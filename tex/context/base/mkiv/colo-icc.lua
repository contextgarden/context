if not modules then modules = { } end modules ['colo-icc'] = {
    version   = 1.000,
    comment   = "companion to colo-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local char, byte, gsub, match, format, strip = string.char, string.byte, string.gsub, string.match, string.format, string.strip
local readstring, readnumber = io.readstring, io.readnumber
local band = bit32.band
local next = next

local colors = attributes and attributes.colors or { } -- when used in mtxrun

local report_colors = logs.reporter("colors","icc")

local R, Cs, lpegmatch = lpeg.R, lpeg.Cs, lpeg.match

local invalid = R(char(0)..char(31))
local cleaned = invalid^0 * Cs((1-invalid)^0)

function colors.iccprofile(filename,verbose)
    local fullname = resolvers.findfile(filename,"icc") or ""
    if fullname == "" then
        local locate = resolvers.finders.byscheme -- not in mtxrun
        if locate then
            fullname = locate("loc",filename)
        end
    end
    if fullname == "" then
        report_colors("profile %a cannot be found",filename)
        return nil, false
    end
    local f = io.open(fullname,"rb")
    if not f then
        report_colors("profile %a cannot be loaded",fullname)
        return nil, false
    end
    local header =  {
        size               = readnumber(f,4),
        cmmtype            = readnumber(f,4),
        version            = readnumber(f,4),
        deviceclass        = strip(readstring(f,4)),
        colorspace         = strip(readstring(f,4)),
        connectionspace    = strip(readstring(f,4)),
        datetime           = {
            year    = readnumber(f,2),
            month   = readnumber(f,2),
            day     = readnumber(f,2),
            hour    = readnumber(f,2),
            minutes = readnumber(f,2),
            seconds = readnumber(f,2),
        },
        filesignature      = strip(readstring(f,4)),
        platformsignature  = strip(readstring(f,4)),
        options            = readnumber(f,4),
        devicemanufacturer = strip(readstring(f,4)),
        devicemodel        = strip(readstring(f,4)),
        deviceattributes   = readnumber(f,4),
        renderingintent    = readnumber(f,4),
        illuminantxyz      = {
            x = readnumber(f,4),
            y = readnumber(f,4),
            z = readnumber(f,4),
        },
        profilecreator     = readnumber(f,4),
        id                 = strip(readstring(f,16)),
    }
    local tags = { }
    for i=1,readnumber(f,128,4) do
        tags[readstring(f,4)] = {
            offset = readnumber(f,4),
            length = readnumber(f,4),
        }
    end
    local o = header.options
    header.options =
        o == 0 and "embedded"  or
        o == 1 and "dependent" or "unknown"
    local d = header.deviceattributes
    header.deviceattributes = {
        [band(d,1) ~= 0 and "transparency" or "reflective"] = true,
        [band(d,2) ~= 0 and "mate"         or "glossy"    ] = true,
        [band(d,3) ~= 0 and "negative"     or "positive"  ] = true,
        [band(d,4) ~= 0 and "bw"           or "color"     ] = true,
    }
    local r = header.renderingintent
    header.renderingintent =
        r == 0 and "perceptual" or
        r == 1 and "relative"   or
        r == 2 and "saturation" or
        r == 3 and "absolute"   or "unknown"
    for tag, spec in next, tags do
        if tag then
            local offset, length = spec.offset, spec.length
            local variant = readstring(f,offset,4)
            if variant == "text" or variant == "desc" then
                local str = readstring(f,length-4)
                tags[tag] = {
                    data    = str,
                    cleaned = lpegmatch(cleaned,str),
                }
            else
                if verbose then
                    report_colors("ignoring tag %a or type %a in profile %a",tag,variant,fullname)
                end
                tags[tag] = nil
            end
        end
    end
    f:close()
    local profile = {
        filename = filename,
        fullname = fullname,
        header   = header,
        tags     = tags,
    }
    report_colors("profile %a loaded",fullname)
    return profile, true
end

-- This is just some fun stuff I decided to check out when I was making sure that
-- the 2020 metafun manual could be processed with lmtx 2021. Color conversion has
-- been part of ConTeXt from the start but it has been extended to the less commonly
-- used color spaces. We already do some CIE but didn't have lab converters to play
-- with (although I had some MetaPost done for a friend long ago). So, when we moved
-- to lmtx it made sense to also move some into the core. When searching for info
-- I ran into some formulas for lab/xyz: http://www.easyrgb.com/en/math.php and
-- http://www.brucelindbloom.com/ are useful resources. I didn't touch existing
-- code (as it works ok).
--
-- local illuminants = { -- 2=CIE 1931 10=CIE 1964
--     A   = { [2] = { 109.850, 100,  35.585 }, [10] = { 111.144, 100,  35.200 } }, -- incandescent/tungsten
--     B   = { [2] = {  99.093, 100,  85.313 }, [10] = {  99.178, 100,  84.349 } }, -- old direct sunlight at noon
--     C   = { [2] = {  98.074, 100, 118.232 }, [10] = {  97.285, 100, 116.145 } }, -- old daylight
--     D50 = { [2] = {  96.422, 100,  82.521 }, [10] = {  96.720, 100,  81.427 } }, -- icc profile pcs
--     D55 = { [2] = {  95.682, 100,  92.149 }, [10] = {  95.799, 100,  90.926 } }, -- mid-morning daylight
--     D65 = { [2] = {  95.047, 100, 108.883 }, [10] = {  94.811, 100, 107.304 } }, -- daylight, srgb, adobe-rgb
--     D75 = { [2] = {  94.972, 100, 122.638 }, [10] = {  94.416, 100, 120.641 } }, -- north sky daylight
--     E   = { [2] = { 100.000, 100, 100.000 }, [10] = { 100.000, 100, 100.000 } }, -- equal energy
--     F1  = { [2] = {  92.834, 100, 103.665 }, [10] = {  94.791, 100, 103.191 } }, -- daylight fluorescent
--     F2  = { [2] = {  99.187, 100,  67.395 }, [10] = { 103.280, 100,  69.026 } }, -- cool fluorescent
--     F3  = { [2] = { 103.754, 100,  49.861 }, [10] = { 108.968, 100,  51.965 } }, -- white fluorescent
--     F4  = { [2] = { 109.147, 100,  38.813 }, [10] = { 114.961, 100,  40.963 } }, -- warm white fluorescent
--     F5  = { [2] = {  90.872, 100,  98.723 }, [10] = {  93.369, 100,  98.636 } }, -- daylight fluorescent
--     F6  = { [2] = {  97.309, 100,  60.191 }, [10] = { 102.148, 100,  62.074 } }, -- lite white fluorescent
--     F7  = { [2] = {  95.044, 100, 108.755 }, [10] = {  95.792, 100, 107.687 } }, -- daylight fluorescent, d65 simulator
--     F8  = { [2] = {  96.413, 100,  82.333 }, [10] = {  97.115, 100,  81.135 } }, -- sylvania f40, d50 simulator
--     F9  = { [2] = { 100.365, 100,  67.868 }, [10] = { 102.116, 100,  67.826 } }, -- cool white fluorescent
--     F10 = { [2] = {  96.174, 100,  81.712 }, [10] = {  99.001, 100,  83.134 } }, -- ultralume 50, philips tl85
--     F11 = { [2] = { 100.966, 100,  64.370 }, [10] = { 103.866, 100,  65.627 } }, -- ultralume 40, philips tl84
--     F12 = { [2] = { 108.046, 100,  39.228 }, [10] = { 111.428, 100,  40.353 } }, -- ultralume 30, philips tl83
-- }
--
-- local D65  = illuminants.D65
-- local D652 = {  95.047, 100, 108.883 }
--
-- local function labref(illuminate,observer)
--     local r = illuminants[illuminant or "D65"] or D65
--     return r[observer or 2] or r[2] or D652
-- end
--
-- This is hardly useful but nice for metafun demos:

local D652 = {  95.047, 100, 108.883 }

local function xyztolab(x,y,z,mapping)
    if not mapping then
        mapping = D652
    end
    x = x / mapping[1]
    y = y / mapping[2]
    z = z / mapping[3]
    x = (x > 0.008856) and x^(1/3) or (7.787 * x) + (16/116)
    y = (y > 0.008856) and y^(1/3) or (7.787 * y) + (16/116)
    z = (z > 0.008856) and z^(1/3) or (7.787 * z) + (16/116)
    return
        116 * y  - 16,
        500 * (x - y),
        200 * (y - z)
end

local function labtoxyz(l,a,b,mapping)
    if not mapping then
        mapping = D652
    end
    local y = (l + 16) / 116
    local x = a / 500 + y
    local z = y - b / 200
    return
        mapping[1] * ((x^3 > 0.008856) and x^3 or (x - 16/116) / 7.787),
        mapping[2] * ((y^3 > 0.008856) and y^3 or (y - 16/116) / 7.787),
        mapping[3] * ((z^3 > 0.008856) and z^3 or (z - 16/116) / 7.787)
end

local function xyztorgb(x,y,z) -- D65/2°
    local r = (x *  3.2404542 + y * -1.5371385 + z * -0.4985314) / 100
    local g = (x * -0.9692660 + y *  1.8760108 + z *  0.0415560) / 100
    local b = (x *  0.0556434 + y * -0.2040259 + z *  1.0572252) / 100
    r = (r > 0.0031308) and (1.055 * r^(1/2.4) - 0.055) or (12.92 * r)
    g = (g > 0.0031308) and (1.055 * g^(1/2.4) - 0.055) or (12.92 * g)
    b = (b > 0.0031308) and (1.055 * b^(1/2.4) - 0.055) or (12.92 * b)
    if r < 0 then r = 0 elseif r > 1 then r = 1 end
    if g < 0 then g = 0 elseif g > 1 then g = 1 end
    if b < 0 then b = 0 elseif b > 1 then b = 1 end
    return r, g, b
end

local function rgbtoxyz(r,g,b)
    r = 100 * ((r > 0.04045) and ((r + 0.055)/1.055)^2.4 or (r / 12.92))
    g = 100 * ((g > 0.04045) and ((g + 0.055)/1.055)^2.4 or (g / 12.92))
    b = 100 * ((b > 0.04045) and ((b + 0.055)/1.055)^2.4 or (b / 12.92))
    return
        r * 0.4124 + g * 0.3576 + b * 0.1805,
        r * 0.2126 + g * 0.7152 + b * 0.0722,
        r * 0.0193 + g * 0.1192 + b * 0.9505
end

local function labtorgb(l,a,b,mapping)
    return xyztorgb(labtoxyz(l,a,b,mapping))
end

colors.xyztolab = xyztolab
colors.labtoxyz = labtoxyz
colors.xyztorgb = xyztorgb
colors.rgbtoxyz = rgbtoxyz
colors.labtorgb = labtorgb
