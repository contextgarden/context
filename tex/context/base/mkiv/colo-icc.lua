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
