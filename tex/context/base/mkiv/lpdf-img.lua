if not modules then modules = { } end modules ['lpdf-img'] = {
    version   = 1.001,
    comment   = "companion to lpdf-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local concat, remove, insert = table.concat, table.remove, table.insert
local ceil = math.ceil
local char, find = string.char, string.find
local idiv = number.idiv
local band, rshift = bit32.band, bit32.rshift

local loaddata             = io.loaddata
local setmetatableindex    = table.setmetatableindex

local streams              = utilities.streams
local openstring           = streams.openstring
local readstring           = streams.readstring
local readbytetable        = streams.readbytetable

local lpdf                 = lpdf or { }
local pdfdictionary        = lpdf.dictionary
local pdfarray             = lpdf.array
local pdfconstant          = lpdf.constant
local pdfstring            = lpdf.string
local pdfflushstreamobject = lpdf.flushstreamobject
local pdfreference         = lpdf.reference

local pdfmajorversion      = lpdf.majorversion
local pdfminorversion      = lpdf.minorversion

local createimage          = images.create

local trace                = false

local report_jpg           = logs.reporter("graphics","jpg")
local report_jp2           = logs.reporter("graphics","jp2")
local report_png           = logs.reporter("graphics","png")

trackers.register("graphics.backend", function(v) trace = v end)

local injectors = { }
lpdf.injectors  = injectors

local chars = setmetatableindex(function(t,k) -- share this one
    local v = (k <= 0 and "\000") or (k >= 255 and "\255") or char(k)
    t[k] = v
    return v
end)

do

    function injectors.jpg(specification)
        if specification.error then
            return
        end
        local filename = specification.filename
        if not filename then
            return
        end
        local colorspace  = specification.colorspace or jpg_gray
        local decodearray = nil
        ----- procset     = colorspace == 0 and "image b" or "image c"
        if colorspace == 1 then
            colorspace = "DeviceGray"
        elseif colorspace == 2 then
            colorspace = "DeviceRGB"
        elseif colorspace == 3 then
            colorspace  = "DeviceCMYK"
            decodearray = pdfarray { 1, 0, 1, 0, 1, 0, 1, 0 }
        end
        -- todo: set filename
        local xsize      = specification.xsize
        local ysize      = specification.ysize
        local colordepth = specification.colordepth
        local content    = loaddata(filename)
        local xobject    = pdfdictionary {
            Type             = pdfconstant("XObject"),
            Subtype          = pdfconstant("Image"),
         -- BBox             = pdfarray { 0, 0, xsize, ysize },
            Width            = xsize,
            Height           = ysize,
            BitsPerComponent = colordepth,
            Filter           = pdfconstant("DCTDecode"),
            ColorSpace       = pdfconstant(colorspace),
            Decode           = decodearray,
            Length           = #content, -- specification.length
        } + specification.attr
        if trace then
            report_jpg("%s: width %i, height %i, colordepth %i, size %i",filename,xsize,ysize,colordepth,#content)
        end
        return createimage {
            bbox     = { 0, 0, specification.width/xsize, specification.height/ysize }, -- mandate
            nolength = true,
            nobbox   = true,
            notype   = true,
            stream   = content,
            attr     = xobject(),
        }
    end

end

do

    function injectors.jp2(specification)
        if specification.error then
            return
        end
        local filename = specification.filename
        if not filename then
            return
        end
        -- todo: set filename
        local xsize   = specification.xsize
        local ysize   = specification.ysize
        local content = loaddata(filename)
        local xobject = pdfdictionary {
            Type    = pdfconstant("XObject"),
            Subtype = pdfconstant("Image"),
            BBox    = pdfarray { 0, 0, xsize, ysize },
            Width   = xsize,
            Height  = ysize,
            Filter  = pdfconstant("JPXDecode"),
            Length  = #content, -- specification.length
        } + specification.attr
        if trace then
            report_jp2("%s: width %i, height %i, size %i",filename,xsize,ysize,#content)
        end
        return createimage {
            bbox     = { 0, 0, specification.width/xsize, specification.height/ysize }, -- mandate
            nolength = true,
            nobbox   = true,
            notype   = true,
            stream   = content,
            attr     = xobject(),
        }
    end

end

do

    -- We don't like interlaced files. You can deinterlace them beforehand because otherwise
    -- each run you add runtime. Actually, even masked images can best be converted to PDF
    -- beforehand.

    -- The amount of code is larger that I like and looks somewhat redundant but we sort of
    -- optimize a few combinations that happen often.

    local function convert(t,len)
        if len then
local n = 0
            for i=1,#t,len do
                t[i] = ""
n = n + 1
            end
        end
        for i=1,#t do
            local ti = t[i]
            if ti ~= "" then
                t[i] = chars[ti]
            end
        end
        return concat(t)
    end

    local function zero(t,k)
        return 0
    end

    local function bump(txt,t,xsize,ysize,bpp)
        local l = xsize * bpp + 1
        print(txt,">",xsize,ysize,bpp,l)
        for i=1,ysize do
            local f = (i-1) * l + 1
            print(txt,i,":",concat(t," ",f,f+l-1))
        end
    end

    local function decodeall(t,xsize,ysize,bpp)
        local len  = xsize * bpp + 1
        local n    = 1
        local m    = len - 1
        for i=1,ysize do
            local filter = t[n]
t[n] = 0 -- not needed
            if filter == 0 then
            elseif filter == 1 then
                for j=n+bpp+1,n+m do
                    t[j] = (t[j] + t[j-bpp]) % 256
                end
            elseif filter == 2 then
                for j=n+1,n+m do
                    t[j] = (t[j] + t[j-len]) % 256
                end
            elseif filter == 3 then
                for j=n+1,n+bpp do
                    t[j] = (t[j] + idiv(t[j-len],2)) % 256
                end
                for j=n+bpp+1,n+m do
                    t[j] = (t[j] + idiv(t[j-bpp] + t[j-len],2)) % 256
                end
            elseif filter == 4 then
                for j=n+1,n+bpp do
                    local p = j - len
                    local b = t[p]
                    if b < 0 then
                        b = - b
                    end
                    if b > 0 then
                        t[j] = (t[j] + b) % 256
                    end
                end
                for j=n+bpp+1,n+m do
                    local p = j - len
                    local a = t[j-bpp]
                    local b = t[p]
                    local c = t[p-bpp]
                    local pa = b - c
                    local pb = a - c
                    local pc = pa + pb
                    if pa < 0 then pa = - pa end
                    if pb < 0 then pb = - pb end
                    if pc < 0 then pc = - pc end
                    t[j] = (t[j] + ((pa <= pb and pa <= pc and a) or (pb <= pc and b) or c)) % 256
                end
            end
            n = n + len
        end
    end

    local xstart = { 0, 4, 0, 2, 0, 1, 0 }
    local xstep  = { 8, 8, 4, 4, 2, 2, 1 }
    local ystart = { 0, 0, 4, 0, 2, 0, 1 }
    local ystep  = { 8, 8, 8, 4, 4, 2, 2 }
    ----- xmax   = { 8, 4, 4, 2, 2, 1, 1 } -- for block fill
    ----- ymax   = { 8, 8, 4, 4, 2, 2, 1 } -- for block fill

    local function newoutput(width,height)
        local t = { }
        for i=1,height*width do
            t[i] = 0
        end
        return t
    end

    local function expand(t,xsize,ysize,parts,factor) -- we don't compact
        local o = { }
        local k = 0
        local l = ceil(xsize*parts/8) + 1
        local n = 1
        if factor then
            if parts == 4 then
                for i=1,ysize do
                    k = k + 1 ; o[k] = t[n]
                    for j=n+1,n+l do
                        local v = t[j]
                        k = k + 1 ; o[k] = band(rshift(v,4),0x0F) * 0x11 ; k = k + 1 ; o[k] = band(rshift(v,0),0x0F) * 0x11
                    end
                    k = i * (xsize + 1)
                    n = n + l
                end
            elseif parts == 2 then
                for i=1,ysize do
                    k = k + 1 ; o[k] = t[n]
                    for j=n+1,n+l do
                        local v = t[j]
                        k = k + 1 ; o[k] = band(rshift(v,6),0x03) * 0x55 ; k = k + 1 ; o[k] = band(rshift(v,4),0x03) * 0x55
                        k = k + 1 ; o[k] = band(rshift(v,2),0x03) * 0x55 ; k = k + 1 ; o[k] = band(rshift(v,0),0x03) * 0x55
                    end
                    k = i * (xsize + 1)
                    n = n + l
                end
            else
                for i=1,ysize do
                    k = k + 1 ; o[k] = t[n]
                    for j=n+1,n+l do
                        local v = t[j]
                        k = k + 1 ; o[k] = band(rshift(v,7),0x01) * 0xFF ; k = k + 1 ; o[k] = band(rshift(v,6),0x01) * 0xFF
                        k = k + 1 ; o[k] = band(rshift(v,5),0x01) * 0xFF ; k = k + 1 ; o[k] = band(rshift(v,4),0x01) * 0xFF
                        k = k + 1 ; o[k] = band(rshift(v,3),0x01) * 0xFF ; k = k + 1 ; o[k] = band(rshift(v,2),0x01) * 0xFF
                        k = k + 1 ; o[k] = band(rshift(v,1),0x01) * 0xFF ; k = k + 1 ; o[k] = band(rshift(v,0),0x01) * 0xFF
                    end
                    k = i * (xsize + 1)
                    n = n + l
                end
            end
        else
            if parts == 4 then
                for i=1,ysize do
                    k = k + 1 ; o[k] = t[n]
                    for j=n+1,n+l do
                        local v = t[j]
                        k = k + 1 ; o[k] = band(rshift(v,4),0x0F) ; k = k + 1 ; o[k] = band(rshift(v,0),0x0F)
                    end
                    k = i * (xsize + 1)
                    n = n + l
                end
            elseif parts == 2 then
                for i=1,ysize do
                    k = k + 1 ; o[k] = t[n]
                    for j=n+1,n+l do
                        local v = t[j]
                        k = k + 1 ; o[k] = band(rshift(v,6),0x03) ; k = k + 1 ; o[k] = band(rshift(v,4),0x03)
                        k = k + 1 ; o[k] = band(rshift(v,2),0x03) ; k = k + 1 ; o[k] = band(rshift(v,0),0x03)
                    end
                    k = i * (xsize + 1)
                    n = n + l
                end
            else
                for i=1,ysize do
                    k = k + 1 ; o[k] = t[n]
                    for j=n+1,n+l do
                        local v = t[j]
                        k = k + 1 ; o[k] = band(rshift(v,7),0x01) ; k = k + 1 ; o[k] = band(rshift(v,6),0x01)
                        k = k + 1 ; o[k] = band(rshift(v,5),0x01) ; k = k + 1 ; o[k] = band(rshift(v,4),0x01)
                        k = k + 1 ; o[k] = band(rshift(v,3),0x01) ; k = k + 1 ; o[k] = band(rshift(v,2),0x01)
                        k = k + 1 ; o[k] = band(rshift(v,1),0x01) ; k = k + 1 ; o[k] = band(rshift(v,0),0x01)
                    end
                    k = i * (xsize + 1)
                    n = n + l
                end
            end
        end
        for i=#o,k+1,-1 do
            o[i] = nil
        end
        return o
    end

    local function deinterlaceXX(s,xsize,ysize,bytes,parts,factor)
        local output = newoutput(xsize*bytes,ysize)
        for pass=1,7 do
            local ystart = ystart[pass]
            local ystep  = ystep[pass]
            local xstart = xstart[pass]
            local xstep  = xstep[pass]
            local nx     = idiv(xsize + xstep - xstart - 1,xstep)
            local ny     = idiv(ysize + ystep - ystart - 1,ystep)
            if nx > 0 and ny > 0 then
                local input
                if parts then
                    local nxx = ceil(nx*parts/8)
                    input = readbytetable(s,ny*(nxx+1))
                    setmetatableindex(input,zero)
                    decodeall(input,nxx,ny,bytes)
                    input = expand(input,nx,ny,parts,factor)
                else
                    input = readbytetable(s,ny*(nx*bytes+1))
                    setmetatableindex(input,zero)
                    decodeall(input,nx,ny,bytes)
                end
                local l = nx*bytes + 1
                for i=ny,1,-1 do
                    remove(input,(i-1)*l+1)
                end
                local xstep  = xstep * bytes
                local xstart = xstart * bytes
                local xsize  = xsize * bytes
                local target = ystart * xsize + xstart + 1
                local ystep  = ystep * xsize
                local start  = 1
                local blobs  = bytes - 1
                for j=0,ny-1 do
                    local target = target + j * ystep
                    for i=1,nx do
                        for i=0,blobs do
                            output[target+i] = input[start]
                            start= start + 1
                        end
                        target = target + xstep
                    end
                end
            end
        end
        return output
    end

    local function deinterlaceYY(s,xsize,ysize,bytes,parts,factor)
        local input
        if parts then
            local nxx = ceil(xsize*parts/8)
            input = readbytetable(s,ysize*(nxx+1))
            setmetatableindex(input,zero)
            decodeall(input,nxx,ysize,bytes)
            input = expand(input,xsize,ysize,parts,factor)
        else
            input = readbytetable(s,ysize*(xsize*bytes+1))
            setmetatableindex(input,zero)
            decodeall(input,xsize,ysize,bytes)
        end
        local l = xsize*bytes + 1
        local n = 1
        for i=1,ysize do
            input[n] = ""
            n = n + l
        end
        return input
    end

    local function analyze(colordepth,colorspace,palette,mask)
        local bytes, parts, factor
        if palette then
            if colordepth == 16 then
                return 2, false, false
            elseif colordepth == 8 then
                return 1, false, false
            elseif colordepth == 4 then
                return 1, 4, false
            elseif colordepth == 2 then
                return 1, 2, false
            elseif colordepth == 1 then
                return 1, 1, false
            end
        elseif colorspace == "DeviceGray" then
            if colordepth == 16 then
                return mask and 4 or 2, false, false
            elseif colordepth == 8 then
                return mask and 2 or 1, false, false
            elseif colordepth == 4 then
                return 1, 4, true
            elseif colordepth == 2 then
                return 1, 2, true
            elseif colordepth == 1 then
                return 1, 1, true
            end
        else
            if colordepth == 16 then
                return mask and 8 or 6, false, false
            elseif colordepth == 8 then
                return mask and 4 or 3, false, false
            elseif colordepth == 4 then
                return 3, 4, true
            elseif colordepth == 2 then
                return 3, 2, true
            elseif colordepth == 1 then
                return 3, 1, true
            end
        end
        return false, false, false
    end

    local function deinterlace(content,xsize,ysize,colordepth,colorspace,palette,mask)
        local bytes, parts, factor = analyze(colordepth,colorspace,palette,mask)
        if bytes then
            content = zlib.decompress(content)
            local s = openstring(content)
            local r = deinterlaceXX(s,xsize,ysize,bytes,parts,factor)
            return r, parts and 8 or false
        end
    end

    local function decompose(content,xsize,ysize,colordepth,colorspace,palette,mask)
        local bytes, parts, factor = analyze(colordepth,colorspace,palette,mask)
        if bytes then
            content = zlib.decompress(content)
            local s = openstring(content)
            local r = deinterlaceYY(s,xsize,ysize,bytes,parts,factor)
            return r, parts and 8 or false
        end
    end

    -- 1 (palette used), 2 (color used), and 4 (alpha channel used)

    -- paeth:
    --
    -- p  = a + b - c
    -- pa = abs(p - a) => a + b - c - a => b - c
    -- pb = abs(p - b) => a + b - c - b => a - c
    -- pc = abs(p - c) => a + b - c - c => a + b - c - c => a - c + b - c => pa + pb

    local function prepareimage(content,xsize,ysize,depth,colorspace,mask)
        local bpp = (depth == 16 and 2 or 1) * ((colorspace == "DeviceRGB" and 3 or 1) + mask)        local len = bpp * xsize + 1
        local s   = openstring(content)
        local t   = readbytetable(s,#content)
        setmetatableindex(t,zero)
        return t, bpp, len
    end

    local function filtermask08(xsize,ysize,t,bpp,len,n)
        local mask = { }
        local l = 0
        local m = len - n
        for i=1,ysize do
            for j=n+bpp,n+m,bpp do
                l = l + 1 ; mask[l] = chars[t[j]] ; t[j] = ""
            end
            n = n + len
        end
        return concat(mask)
    end

    local function filtermask16(xsize,ysize,t,bpp,len,n)
        local mask = { }
        local l = 0
        local m = len - n
        for i=1,ysize do
            for j=n+bpp-1,n+m-1,bpp do
                l = l + 1 ; mask[l] = chars[t[j]] ; t[j] = ""
                j = j + 1
                l = l + 1 ; mask[l] = chars[t[j]] ; t[j] = ""
            end
            n = n + len
        end
        return concat(mask)
    end

    local function decodemask08(content,xsize,ysize,depth,colorspace)
        local t, bpp, len = prepareimage(content,xsize,ysize,depth,colorspace,1)
        local bpp2 = mask and (bpp + bpp) or bpp
        local n = 1
        local m = len - 1
        for i=1,ysize do
            local filter = t[n]
            if filter == 0 then
            elseif filter == 1 then
                for j=n+bpp2,n+m,bpp do
                    t[j] = (t[j] + t[j-bpp]) % 256
                end
            elseif filter == 2 then
                for j=n+bpp,n+m,bpp do
                    t[j] = (t[j] + t[j-len]) % 256
                end
            elseif filter == 3 then
                local j = n + bpp
                t[j] = (t[j] + idiv(t[j-len],2)) % 256
                for j=n+bpp2,n+m,bpp do
                    t[j] = (t[j] + idiv(t[j-bpp] + t[j-len],2)) % 256
                end
            elseif filter == 4 then
                local j = n + bpp
                local p = j - len
                local b = t[p]
                if b < 0 then
                    b = - b
                end
                if b > 0 then
                    t[j] = (t[j] + b) % 256
                end
                for j=n+bpp2,n+m,bpp do
                    local p = j - len
                    local a = t[j-bpp]
                    local b = t[p]
                    local c = t[p-bpp]
                    local pa = b - c
                    local pb = a - c
                    local pc = pa + pb
                    if pa < 0 then pa = - pa end
                    if pb < 0 then pb = - pb end
                    if pc < 0 then pc = - pc end
                    t[j] = (t[j] + ((pa <= pb and pa <= pc and a) or (pb <= pc and b) or c)) % 256
                end
            end
            n = n + len
        end
        local mask = filtermask08(xsize,ysize,t,bpp,len,1)
        return convert(t), mask
    end

    local function decodemask16(content,xsize,ysize,depth,colorspace)
        local t, bpp, len = prepareimage(content,xsize,ysize,depth,colorspace,1)
        local bpp2 = bpp + bpp
        local n = 1
        local m = len - 1
        for i=1,ysize do
            local filter = t[n]
            if filter == 0 then
            elseif filter == 1 then
                for j=n+bpp2,n+m,bpp do
                    local k = j - 1
                    t[j] = (t[j] + t[j-bpp]) % 256
                    t[k] = (t[k] + t[k-bpp]) % 256
                end
            elseif filter == 2 then
                for j=n+bpp,n+m,bpp do
                    local k = j - 1
                    t[j] = (t[j] + t[j-len]) % 256
                    t[k] = (t[k] + t[k-len]) % 256
                end
            elseif filter == 3 then
                local j = n + bpp
                local k = j - 1
                t[j] = (t[j] + idiv(t[j-len],2)) % 256
                t[k] = (t[k] + idiv(t[k-len],2)) % 256
                for j=n+bpp2,n+m,bpp do
                    local k = j - 1
                    t[j] = (t[j] + idiv(t[j-bpp] + t[j-len],2)) % 256
                    t[k] = (t[k] + idiv(t[k-bpp] + t[k-len],2)) % 256
                end
            elseif filter == 4 then
                for i=-1,0 do
                    local j = n + bpp + i
                    local p = j - len
                    local b = t[p]
                    if b < 0 then
                        b = - b
                    end
                    if b > 0 then
                        t[j] = (t[j] + b) % 256
                    end
                    for j=n+i+bpp2,n+i+m,bpp do
                        local p = j - len
                        local a = t[j-bpp]
                        local b = t[p]
                        local c = t[p-bpp]
                        local pa = b - c
                        local pb = a - c
                        local pc = pa + pb
                        if pa < 0 then pa = - pa end
                        if pb < 0 then pb = - pb end
                        if pc < 0 then pc = - pc end
                        t[j] = (t[j] + ((pa <= pb and pa <= pc and a) or (pb <= pc and b) or c)) % 256
                    end
                end
            end
            n = n + len
        end
        local mask = filtermask16(xsize,ysize,t,bpp,len,1)
        return convert(t), mask
    end

    local function full(t,k) local v = "\xFF" t[k] = v return v end

    local function create(content,palette,transparent,xsize,ysize,colordepth,colorspace)
        if palette then
            --
            local s = openstring(transparent)
            local n = #transparent
            local r = { }
            for i=0,n-1 do
                r[i] = readstring(s,1)
            end
            setmetatableindex(r,full)
            --
            local c = zlib.decompress(content)
            local s = openstring(c)
            --
            local o = { }
            local len = ceil(xsize*colordepth/8) + 1
            local m = len - 1
            local u = setmetatableindex(zero)
            --
            for i=1,ysize do
                local t = readbytetable(s,len)
                local k = (i-1) * xsize
                local filter = t[1]
                if filter == 0 then
                elseif filter == 1 then
                    for j=3,len do
                        t[j] = (t[j] + t[j-1]) % 256
                    end
                elseif filter == 2 then
                    for j=2,len do
                        t[j] = (t[j] + u[j]) % 256
                    end
                elseif filter == 3 then
                    local j = 2
                    t[j] = (t[j] + idiv(u[j],2)) % 256
                    for j=3,len do
                        t[j] = (t[j] + idiv(t[j-1] + u[j],2)) % 256
                    end
                elseif filter == 4 then
                    local j = 2
                    local p = j - len
                    local b = t[p]
                    if b < 0 then
                        b = - b
                    end
                    if b > 0 then
                        t[j] = (t[j] + b) % 256
                    end
                    for j=3,len do
                        local p = j - len
                        local a = t[j-1]
                        local b = t[p]
                        local c = t[p-1]
                        local pa = b - c
                        local pb = a - c
                        local pc = pa + pb
                        if pa < 0 then pa = - pa end
                        if pb < 0 then pb = - pb end
                        if pc < 0 then pc = - pc end
                        t[j] = (t[j] + ((pa <= pb and pa <= pc and a) or (pb <= pc and b) or c)) % 256
                    end
                end
                if colordepth == 8 then
                    for j=2,len do
                        local v = t[j]
                        k = k + 1 ; o[k] = r[v] or "\xFF"
                    end
                elseif colordepth == 4 then
                    for j=2,len do
                        local v = t[j]
                        k = k + 1 ; o[k] = r[band(rshift(v,4),0x0F)]
                        k = k + 1 ; o[k] = r[band(rshift(v,0),0x0F)]
                    end
                elseif colordepth == 2 then
                    for j=2,len do
                        local v = t[j]
                        k = k + 1 ; o[k] = r[band(rshift(v,6),0x03)]
                        k = k + 1 ; o[k] = r[band(rshift(v,4),0x03)]
                        k = k + 1 ; o[k] = r[band(rshift(v,2),0x03)]
                        k = k + 1 ; o[k] = r[band(rshift(v,0),0x03)]
                    end
                else
                    for j=2,len do
                        local v = t[j]
                        k = k + 1 ; o[k] = r[band(rshift(v,7),0x01)]
                        k = k + 1 ; o[k] = r[band(rshift(v,6),0x01)]
                        k = k + 1 ; o[k] = r[band(rshift(v,5),0x01)]
                        k = k + 1 ; o[k] = r[band(rshift(v,4),0x01)]
                        k = k + 1 ; o[k] = r[band(rshift(v,3),0x01)]
                        k = k + 1 ; o[k] = r[band(rshift(v,2),0x01)]
                        k = k + 1 ; o[k] = r[band(rshift(v,2),0x01)]
                        k = k + 1 ; o[k] = r[band(rshift(v,1),0x01)]
                    end
                end
                u = t
            end
            return concat(o,"",1,ysize * xsize)
        end
    end

    local alwaysdecode = false

    directives.register("graphics.png.decode", function(v)
        alwaysdecode = v
    end)

    function injectors.png(specification)
        if specification.error then
            return
        end
        local filename = specification.filename
        if not filename then
            return
        end
        local colorspace = specification.colorspace
        if not colorspace then
            return
        end
        local interlace = specification.interlace or 0
        if interlace == 1 then
            interlace = true
        elseif interlace == 0 then
            interlace = false
        else
            report_png("unknown interlacing %i",interlace)
            return
        end
        local tables = specification.tables
        if not tables then
            return
        end
        local idat = tables.idat
        if not idat then
            return
        end
        local pngfile = io.open(filename,"rb")
        if not pngfile then
            return
        end
        local content = idat(pngfile,true)
        tables.idat = false
        --
     -- if tables.gama then
     --     report_png("ignoring gamma correction")
     -- end
        --
        local xsize       = specification.xsize
        local ysize       = specification.ysize
        local colordepth  = specification.colordepth or 8
        local mask        = false
        local transparent = false
        local palette     = false
        local colors      = 1
        if     colorspace == 0 then    -- gray | image b
            colorspace  = "DeviceGray"
            transparent = true
        elseif colorspace == 2 then    -- rgb | image c
            colorspace  = "DeviceRGB"
            colors      = 3
            transparent = true
        elseif colorspace == 3 then    -- palette | image c+i
            colorspace  = "DeviceRGB"
            palette     = true
            transparent = true
        elseif colorspace == 4 then    -- gray | alpha | image b
            colorspace = "DeviceGray"
            mask       = true
        elseif colorspace == 6 then    -- rgb | alpha | image c
            colorspace = "DeviceRGB"
            colors     = 3
            mask       = true
        else
            report_png("unknown colorspace %i",colorspace)
            return
        end
        --
        if transparent then
            local trns = tables.trns
            if trns then
                transparent = trns(pngfile,true)
                if transparent == "" then
                    transparent = false
                end
                tables.trns = false
            else
                transparent = false
            end
        end
        --
        local decode = alwaysdecode
        local major  = pdfmajorversion()
        local minor  = pdfminorversion()
        if major > 1 then
            -- we're okay
        elseif minor < 5 and colordepth == 16 then
            report_png("16 bit colordepth not supported in pdf < 1.5")
            return
        elseif minor < 4 and (mask or transparent) then
            report_png("alpha channels not supported in pdf < 1.4")
            return
        elseif minor < 2 then
            decode = true
        end
        --
        -- todo: compresslevel (or delegate)
        --
        if palette then
            local plte = tables.plte
            if plte then
                palette = plte(pngfile,true)
                if palette == "" then
                    palette = false
                end
                tables.plte = false
            else
                palette = false
            end
        end
        --
        if interlace then
            local r, p = deinterlace(content,xsize,ysize,colordepth,colorspace,palette,mask)
            if not r then
                return
            end
            if p then
                colordepth = p
            end
            if mask then
                local bpp = (colordepth == 16 and 2 or 1) * ((colorspace == "DeviceRGB" and 3 or 1) + 1)
                local len = bpp * xsize -- + 1
                if colordepth == 8 then -- bpp == 1
                    mask = filtermask08(xsize,ysize,r,bpp,len,0)
                elseif colordepth == 16 then -- bpp == 2
                    mask = filtermask16(xsize,ysize,r,bpp,len,0)
                else
                    report_png("mask can't be split from the image")
                    return
                end
            end
            decode  = true
            content = convert(r)
            content = zlib.compress(content)
        elseif mask then
            local decoder
            if colordepth == 8 then
                decoder = decodemask08
            elseif colordepth == 16 then
                decoder = decodemask16
            end
            if not decoder then
                report_png("mask can't be split from the image")
                return
            end
            content = zlib.decompress(content)
            content, mask = decoder(content,xsize,ysize,colordepth,colorspace)
            content = zlib.compress(content)
            decode  = false
        elseif transparent then
            if palette then
                mask = create(content,palette,transparent,xsize,ysize,colordepth,colorspace)
            else
                pallette = false
            end
        elseif decode then
            local r, p = decompose(content,xsize,ysize,colordepth,colorspace,palette)
            if not r then
                return
            end
            if p then
                colordepth = p
            end
            content = convert(r)
            content = zlib.compress(content)
        end
        if palette then
            palette = pdfarray {
                pdfconstant("Indexed"),
                pdfconstant("DeviceRGB"),
                idiv(#palette,3),
                pdfreference(pdfflushstreamobject(palette)),
            }
        end
        pngfile:close()
        local xobject = pdfdictionary {
            Type             = pdfconstant("XObject"),
            Subtype          = pdfconstant("Image"),
         -- BBox             = pdfarray { 0, 0, xsize, ysize },
            Width            = xsize,
            Height           = ysize,
            BitsPerComponent = colordepth,
            Filter           = pdfconstant("FlateDecode"),
            ColorSpace       = palette or pdfconstant(colorspace),
            Length           = #content,
        } + specification.attr
        if mask then
            local d = pdfdictionary {
                Type             = pdfconstant("XObject"),
                Subtype          = pdfconstant("Image"),
                Width            = xsize,
                Height           = ysize,
                BitsPerComponent = palette and 8 or colordepth,
                ColorSpace       = pdfconstant("DeviceGray"),
            }
            xobject.SMask = pdfreference(pdfflushstreamobject(mask,d()))
        end
        if not decode then
            xobject.DecodeParms  = pdfdictionary {
                Colors           = colors,
                Columns          = xsize,
                BitsPerComponent = colordepth,
                Predictor        = 15,
            }
        end
        if trace then
            report_png("%s: width %i, height %i, colordepth: %i, size: %i, palette %l, mask: %l, transparent %l, decode %l",filename,xsize,ysize,colordepth,#content,palette,mask,transparent,decode)
        end
        return createimage {
            bbox     = { 0, 0, specification.width/xsize, specification.height/ysize }, -- mandate
            nolength = true,
            nobbox   = true,
            notype   = true,
            stream   = content,
            attr     = xobject(),
        }
    end

end

do

    local function pack(specification,what)
        local t = { }
        local n = 0
        local s = specification.colorspace
        local d = specification.data
        local x = specification.xsize
        local y = specification.ysize
        if what == "mask" then
            d = specification.mask
            s = 1
        end
        if s == 1 then
            for i=1,y do
                local r = d[i]
                for j=1,x do
                    n = n + 1 ; t[n] = chars[r[j]]
                end
            end
        elseif s == 2 then
            for i=1,y do
                local r = d[i]
                for j=1,x do
                    local c = r[j]
                    n = n + 1 ; t[n] = chars[c[1]]
                    n = n + 1 ; t[n] = chars[c[2]]
                    n = n + 1 ; t[n] = chars[c[3]]
                end
            end
        elseif s == 3 then
            for i=1,y do
                local r = d[i]
                for j=1,x do
                    local c = r[j]
                    n = n + 1 ; t[n] = chars[c[1]]
                    n = n + 1 ; t[n] = chars[c[2]]
                    n = n + 1 ; t[n] = chars[c[3]]
                    n = n + 1 ; t[n] = chars[c[4]]
                end
            end
        end
        return concat(t)
    end

    function injectors.bitmap(specification)
        local data = specification.data
        if not data then
            return
        end
        local xsize = specification.xsize or 0
        local ysize = specification.ysize or 0
        if xsize == 0 or ysize == 0 then
            return
        end
        local colorspace = specification.colorspace or 1
        if colorspace == 1 then
            colorspace = "DeviceGray"
        elseif colorspace == 2 then
            colorspace = "DeviceRGB"
        elseif colorspace == 3 then
            colorspace  = "DeviceCMYK"
        end
        local colordepth = (specification.colordepth or 2) == 16 or 8
        local content    = pack(specification,"data")
        local mask       = specification.mask
        local xobject    = pdfdictionary {
            Type             = pdfconstant("XObject"),
            Subtype          = pdfconstant("Image"),
            BBox             = pdfarray { 0, 0, xsize, ysize },
            Width            = xsize,
            Height           = ysize,
            BitsPerComponent = colordepth,
            ColorSpace       = pdfconstant(colorspace),
            Length           = #content, -- specification.length
        }
        if mask then
            local d = pdfdictionary {
                Type             = pdfconstant("XObject"),
                Subtype          = pdfconstant("Image"),
                Width            = xsize,
                Height           = ysize,
                BitsPerComponent = colordepth,
                ColorSpace       = pdfconstant("DeviceGray"),
            }
            xobject.SMask = pdfreference(pdfflushstreamobject(pack(specification,"mask"),d()))
        end
        return createimage {
            bbox     = { 0, 0, specification.width/xsize, specification.height/ysize }, -- mandate
         -- nolength = true,
            nobbox   = true,
            notype   = true,
            stream   = content,
            attr     = xobject(),
        }
    end

end
