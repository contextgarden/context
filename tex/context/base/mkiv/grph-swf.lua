if not modules then modules = { } end modules ['grph-swf'] = {
    version   = 1.001,
    comment   = "companion to grph-inc.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- maybe: backends.codeinjections.insertswf

local sub, format, match, byte = string.sub, string.format, string.match, string.byte
local concat = table.concat
local floor = math.floor
local tonumber = tonumber

local readstring     = io.readstring
local readnumber     = io.readnumber
local tobitstring    = number.tobitstring
local todimen        = number.todimen
local nodeinjections = backends.nodeinjections
local figures        = figures
local context        = context

local function getheader(name)
    local f = io.open(name,"rb")
    if not f then
        return
    end
    local signature  = readstring(f,3) -- F=uncompressed, C=compressed (zlib)
    local version    = readnumber(f,1)
    local filelength = readnumber(f,-4)
    local compressed = sub(signature,1,1) == "C"
    local buffer
    if compressed then
        buffer = zlib.decompress(f:read('*a'))
    else
        buffer = f:read(20) -- ('*a')
    end
    f:close()
    -- can be done better now that we have stream readers
    buffer = { match(buffer,"(.)(.)(.)(.)(.)(.)(.)(.)(.)(.)(.)(.)(.)") }
    for i=1,9 do
        buffer[i] = tobitstring(byte(buffer[i]),8,8)
    end
    local framebits = concat(buffer,"",1,9)
    local n = tonumber(sub(framebits,1,5),2)
    local frame = { } -- xmin xmax ymin ymax
    local xmin = tonumber(sub(framebits,6,      5 +   n),2)
    local xmax = tonumber(sub(framebits,6 + 1*n,5 + 2*n),2)
    local ymin = tonumber(sub(framebits,6 + 2*n,5 + 3*n),2)
    local ymax = tonumber(sub(framebits,6 + 3*n,5 + 4*n),2)
    return {
        filename   = name,
        version    = version,
        filelength = filelength,
        framerate  = tonumber(byte(buffer[10]) * 256 + byte(buffer[11])),
        framecount = tonumber(byte(buffer[12]) * 256 + byte(buffer[13])),
     -- framebits  = framebits,
        compressed = compressed,
        width      = floor((xmax - xmin) / 20),
        height     = floor((ymax - ymin) / 20),
        rectangle  = {
            xmin = xmin,
            xmax = xmax,
            ymin = ymin,
            ymax = ymax,
        }
    }
end

function figures.checkers.swf(data)
    local dr, du, ds = data.request, data.used, data.status
    local foundname = du.fullname
    local header = getheader(foundname)
    local width, height = figures.applyratio(dr.width,dr.height,header.width,header.height)
    dr.width, dr.height = width, height
    du.width, du.height, du.foundname = width, height, foundname
    context.startfoundexternalfigure(todimen(width),todimen(height))
        nodeinjections.insertswf {
            foundname = foundname,
            width     = width,
            height    = height,
        --  factor    = number.dimenfactors.bp,
            display   = dr.display,
            controls  = dr.controls,
        --  label     = dr.label,
            resources = dr.resources,
            arguments = dr.arguments,
        }
    context.stopfoundexternalfigure()
    return data
end

figures.includers.swf = figures.includers.nongeneric

figures.registersuffix("swf","swf")
