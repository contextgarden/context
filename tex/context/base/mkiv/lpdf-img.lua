if not modules then modules = { } end modules ['lpdf-img'] = {
    version   = 1.001,
    comment   = "companion to lpdf-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- This started as an experiment but has potential for some (cached) optimizations.
-- At some point we can also use it for fonts. For small images performance is ok
-- with pure lua but for bigger images we can use some helpers. Normally in a
-- typesetting workflow non-interlaced images are used. One should convert
-- interlaced images to more efficient non-interlaced ones (ok, we can cache
-- them if needed).
--
-- The \LUA\ code is slightly optimized so we could have done with less lines if
-- we wanted but best gain a little. The idea is that we collect striped (in stages)
-- so that we can play with substitutions.

local type = type
local concat, move = table.concat, table.move
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

local tobytetable          = string.bytetable

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

local zlibcompress         = flate and flate.zip_compress or zlib.compress
local zlibdecompress       = zlib.decompress -- todo

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
            bbox      = { 0, 0, specification.width/xsize, specification.height/ysize }, -- mandate
            transform = specification.transform,
            nolength  = true,
            nobbox    = true,
            notype    = true,
            stream    = content,
            attr      = xobject(),
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
            bbox      = { 0, 0, specification.width/xsize, specification.height/ysize }, -- mandate
            transform = specification.transform,
            nolength  = true,
            nobbox    = true,
            notype    = true,
            stream    = content,
            attr      = xobject(),
        }
    end

end

do

    -- We don't like interlaced files. You can deinterlace them beforehand because otherwise
    -- each run you add runtime. Actually, even masked images can best be converted to PDF
    -- beforehand.

    -- The amount of code is larger that I like and looks somewhat redundant but we sort of
    -- optimize a few combinations that happen often.

    local pngapplyfilter = pnge and pnge.applyfilter
    local pngsplitmask   = pnge and pnge.splitmask
    local pnginterlace   = pnge and pnge.interlace
    local pngexpand      = pnge and pnge.expand

    local filtermask, decodemask, decodestrip, transpose, expand

    local newindex = lua.newindex
    local newtable = lua.newtable

    local function newoutput(size)
        if newindex then
            return newindex(size,0)
        end
        local t = newtable and newtable(size,0) or { }
        for i=1,size do
            t[i] = 0
        end
        return t
    end

    local function convert(t)
        if type(t) == "table" then
            for i=1,#t do
                local ti = t[i]
                if ti ~= "" then -- soon gone
                    t[i] = chars[ti]
                end
            end
            return concat(t)
        else
            return t
        end
    end

    local function zero(t,k)
        return 0
    end

    local function applyfilter(t,xsize,ysize,bpp)
        local len = xsize * bpp + 1
        local n   = 1
        local m   = len - 1
        for i=1,ysize do
            local filter = t[n]
            t[n] = ""
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
        return t
    end

    local filtermask_l = function (content,xsize,ysize,colordepth,colorspace,hasfilter)
        local mask   = { }
        local bytes  = colordepth == 16 and 2 or 1
        local bpp    = colorspace == "DeviceRGB" and 3 or 1
        local length = #content
        local size   = ysize * xsize * ((bpp+1)*bytes + (hasfilter and 1 or 0))
        local n     = 1
        local l     = 1
        if bytes == 2 then
            if bpp == 1 then
                for i=1,ysize do
                    if hasfilter then
                        content[n] = "" ; n = n + 1
                    end
                    for j=1,xsize do
                        content[n] = chars[content[n]] ; n = n + 1
                        content[n] = chars[content[n]] ; n = n + 1
                        mask[l]    = chars[content[n]] ; l = l + 1
                        content[n] = ""                ; n = n + 1
                        mask[l]    = chars[content[n]] ; l = l + 1
                        content[n] = ""                ; n = n + 1
                    end
                end
            elseif bpp == 3 then
                for i=1,ysize do
                    if hasfilter then
                        content[n] = "" ; n = n + 1
                    end
                    for j=1,xsize do
                        content[n] = chars[content[n]] ; n = n + 1
                        content[n] = chars[content[n]] ; n = n + 1
                        content[n] = chars[content[n]] ; n = n + 1
                        content[n] = chars[content[n]] ; n = n + 1
                        content[n] = chars[content[n]] ; n = n + 1
                        content[n] = chars[content[n]] ; n = n + 1
                        mask[l]    = chars[content[n]] ; l = l + 1
                        content[n] = ""                ; n = n + 1
                        mask[l]    = chars[content[n]] ; l = l + 1
                        content[n] = ""                ; n = n + 1
                    end
                end
            else
                return "", ""
            end
        else
            if bpp == 1 then
                for i=1,ysize do
                    if hasfilter then
                        content[n] = "" ; n = n + 1
                    end
                    for j=1,xsize do
                        content[n] = chars[content[n]] ; n = n + 1
                        mask[l]    = chars[content[n]] ; l = l + 1
                        content[n] = ""                ; n = n + 1
                    end
                end
            elseif bpp == 3 then
                for i=1,ysize do
                    if hasfilter then
                        content[n] = "" ; n = n + 1
                    end
                    for j=1,xsize do
                        content[n] = chars[content[n]] ; n = n + 1
                        content[n] = chars[content[n]] ; n = n + 1
                        content[n] = chars[content[n]] ; n = n + 1
                        mask[l]    = chars[content[n]] ; l = l + 1
                        content[n] = ""                ; n = n + 1
                    end
                end
            else
                return "", ""
            end
        end
        return concat(content), concat(mask)
    end

    local decodemask_l = function(content,xsize,ysize,colordepth,colorspace)
        local bytes  = colordepth == 16 and 2 or 1
        local bpp    = colorspace == "DeviceRGB" and 3 or 1
        local slice  = bytes*(bpp+1)
        local length = #content
        local size   = ysize * xsize * ((bpp+1)*bytes + 1) -- assume filter
        content = openstring(content)
        content = readbytetable(content,length)
        setmetatableindex(content,zero)
        applyfilter(content,xsize,ysize,slice)
        content, mask = filtermask(content,xsize,ysize,colordepth,colorspace,true)
        return content, mask
    end

    local filtermask_c = function(content,xsize,ysize,colordepth,colorspace)
        local bytes = colordepth == 16 and 2 or 1
        local bpp   = colorspace == "DeviceRGB" and 3 or 1
        return pngsplitmask(content,xsize,ysize,bpp,bytes)
    end

    local decodemask_c = function(content,xsize,ysize,colordepth,colorspace)
        local mask   = true
        local filter = false
        local bytes  = colordepth == 16 and 2 or 1
        local bpp    = colorspace == "DeviceRGB" and 3 or 1
        local slice  = bytes * (bpp + 1) -- always a mask
        content      = pngapplyfilter(content,xsize,ysize,slice)
        return pngsplitmask(content,xsize,ysize,bpp,bytes,mask,filter)
    end

    local function decodestrip_l(s,nx,ny,slice)
        local input = readbytetable(s,ny*(nx*slice+1))
        setmetatableindex(input,zero)
        applyfilter(input,nx,ny,slice)
        return input, true
    end

    local function decodestrip_c(s,nx,ny,slice)
        local input = readstring(s,ny*(nx*slice+1))
        input = pngapplyfilter(input,nx,ny,slice)
        return input, false
    end

    local xstart = { 0, 4, 0, 2, 0, 1, 0 }
    local ystart = { 0, 0, 4, 0, 2, 0, 1 }
    local xstep  = { 8, 8, 4, 4, 2, 2, 1 }
    local ystep  = { 8, 8, 8, 4, 4, 2, 2 }

    local xblock = { 8, 4, 4, 2, 2, 1, 1 }
    local yblock = { 8, 8, 4, 4, 2, 2, 1 }

    local function transpose_l(xsize,ysize,slice,pass,input,output,filter)
        local xstart = xstart[pass]
        local xstep  = xstep[pass]
        local ystart = ystart[pass]
        local ystep  = ystep[pass]
        local nx     = idiv(xsize + xstep - xstart - 1,xstep)
        local ny     = idiv(ysize + ystep - ystart - 1,ystep)
        local offset = filter and 1 or 0
        local xstep  = xstep * slice
        local xstart = xstart * slice
        local xsize  = xsize * slice
        local target = ystart * xsize + xstart + 1
        local ystep  = ystep * xsize
        local start  = 1
        local plus   = nx * xstep
        local step   = plus - xstep
        if not output then
            output = newoutput(xsize*(parts or slice)*ysize)
        end
        if slice == 1 then
            for j=0,ny-1 do
                start = start + offset
                local target = target + j * ystep
                for target=target,target+step,xstep do
                    output[target] = input[start]
                    start = start + slice
                end
            end
        elseif slice == 2 then
            for j=0,ny-1 do
                start = start + offset
                local target = target + j * ystep
                for target=target,target+step,xstep do
                    output[target]   = input[start]
                    output[target+1] = input[start+1]
                    start = start + slice
                end
            end
        elseif slice == 3 then
            for j=0,ny-1 do
                start = start + offset
                local target = target + j * ystep
                for target=target,target+step,xstep do
                    output[target]   = input[start]
                    output[target+1] = input[start+1]
                    output[target+2] = input[start+2]
                    start = start + slice
                end
            end
        elseif slice == 4 then
            for j=0,ny-1 do
                start = start + offset
                local target = target + j * ystep
                for target=target,target+step,xstep do
                    output[target]   = input[start]
                    output[target+1] = input[start+1]
                    output[target+2] = input[start+2]
                    output[target+3] = input[start+3]
                    start = start + slice
                end
            end
        else
            local delta = slice - 1
            for j=0,ny-1 do
                start = start + offset
                local target = target + j * ystep
                for target=target,target+step,xstep do
                    move(input,start,start+delta,target,output)
                    start = start + slice
                end
            end
        end
        return output;
    end

    local transpose_c = pnginterlace

 -- print(band(rshift(v,4),0x03),extract(v,4,2))
 -- print(band(rshift(v,6),0x03),extract(v,6,2))

    local function expand_l(t,xsize,ysize,parts,run,factor,filter)
        local size  = ysize * xsize + 1 -- a bit of overshoot, needs testing, probably a few bytes us ok
        local xline = filter and (run+1) or run
        local f     = filter and 1 or 0
        local l     = xline - 1
        local n     = 1
        local o     = newoutput(size)
        local k     = 0
        if factor then
            if parts == 4 then
                for i=1,ysize do
                    for j=n+f,n+l do
                        local v = t[j]
                        if v == 0 then
                            k = k + 2
                        else
                            k = k + 1 ; o[k] = extract4(v,4) * 0x11
                            k = k + 1 ; o[k] = extract4(v,0) * 0x11
                        end
                    end
                    k = i * xsize
                    n = n + xline
                end
            elseif parts == 2 then
                for i=1,ysize do
                    for j=n+f,n+l do
                        local v = t[j]
                        if v == 0 then
                            k = k + 4
                        else
                            k = k + 1 ; o[k] = extract2(v,6) * 0x55
                            k = k + 1 ; o[k] = extract2(v,4) * 0x55
                            k = k + 1 ; o[k] = extract2(v,2) * 0x55
                            k = k + 1 ; o[k] = extract2(v,0) * 0x55
                        end
                    end
                    k = i * xsize
                    n = n + xline
                end
            else
                for i=1,ysize do
                    for j=n+f,n+l do
                        local v = t[j]
                        if v == 0 then
                            k = k + 8
                        else
                            k = k + 1 ; if band(v,0x80) ~= 0 then o[k] = 0xFF end -- o[k] = extract1(v,7) * 0xFF
                            k = k + 1 ; if band(v,0x40) ~= 0 then o[k] = 0xFF end -- o[k] = extract1(v,6) * 0xFF
                            k = k + 1 ; if band(v,0x20) ~= 0 then o[k] = 0xFF end -- o[k] = extract1(v,5) * 0xFF
                            k = k + 1 ; if band(v,0x10) ~= 0 then o[k] = 0xFF end -- o[k] = extract1(v,4) * 0xFF
                            k = k + 1 ; if band(v,0x08) ~= 0 then o[k] = 0xFF end -- o[k] = extract1(v,3) * 0xFF
                            k = k + 1 ; if band(v,0x04) ~= 0 then o[k] = 0xFF end -- o[k] = extract1(v,2) * 0xFF
                            k = k + 1 ; if band(v,0x02) ~= 0 then o[k] = 0xFF end -- o[k] = extract1(v,1) * 0xFF
                            k = k + 1 ; if band(v,0x01) ~= 0 then o[k] = 0xFF end -- o[k] = extract1(v,0) * 0xFF
                        end
                    end
                    k = i * xsize
                    n = n + xline
                end
            end
        else
            if parts == 4 then
                for i=1,ysize do
                    for j=n+f,n+l do
                        local v = t[j]
                        if v == 0 then
                            k = k + 2
                        else
                            k = k + 1 ; o[k] = extract4(v,4)
                            k = k + 1 ; o[k] = extract4(v,0)
                        end
                    end
                    k = i * xsize
                    n = n + xline
                end
            elseif parts == 2 then
                for i=1,ysize do
                    for j=n+f,n+l do
                        local v = t[j]
                        if v == 0 then
                            k = k + 4
                        else
                            k = k + 1 ; o[k] = extract2(v,6)
                            k = k + 1 ; o[k] = extract2(v,4)
                            k = k + 1 ; o[k] = extract2(v,2)
                            k = k + 1 ; o[k] = extract2(v,0)
                        end
                    end
                    k = i * xsize
                    n = n + xline
                end
            else
                for i=1,ysize do
                    for j=n+f,n+l do
                        local v = t[j]
                        if v == 0 then
                            k = k + 8
                        else
                            k = k + 1 ; if band(v,0x80) ~= 0 then o[k] = 1 end -- o[k] = extract1(v,7)
                            k = k + 1 ; if band(v,0x40) ~= 0 then o[k] = 1 end -- o[k] = extract1(v,6)
                            k = k + 1 ; if band(v,0x20) ~= 0 then o[k] = 1 end -- o[k] = extract1(v,5)
                            k = k + 1 ; if band(v,0x10) ~= 0 then o[k] = 1 end -- o[k] = extract1(v,4)
                            k = k + 1 ; if band(v,0x08) ~= 0 then o[k] = 1 end -- o[k] = extract1(v,3)
                            k = k + 1 ; if band(v,0x04) ~= 0 then o[k] = 1 end -- o[k] = extract1(v,2)
                            k = k + 1 ; if band(v,0x02) ~= 0 then o[k] = 1 end -- o[k] = extract1(v,1)
                            k = k + 1 ; if band(v,0x01) ~= 0 then o[k] = 1 end -- o[k] = extract1(v,0)
                        end
                    end
                    k = i * xsize
                    n = n + xline
                end
            end
        end
        for i=size,xsize * ysize +1,-1 do
            o[i] = nil
        end
        return o, false
    end

    local expand_c = pngexpand

    local function analyze(colordepth,colorspace,palette,mask)
     -- return bytes, parts, factor
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

    -- 1 6 4 6 2 6 4 6
    -- 7 7 7 7 7 7 7 7
    -- 5 6 5 6 5 6 5 6
    -- 7 7 7 7 7 7 7 7
    -- 3 6 4 6 3 6 4 6
    -- 7 7 7 7 7 7 7 7
    -- 5 6 5 6 5 6 5 6
    -- 7 7 7 7 7 7 7 7

    local function deinterlace(content,xsize,ysize,colordepth,colorspace,palette,mask)
        local slice, parts, factor = analyze(colordepth,colorspace,palette,mask)
        if slice then
            content = openstring(zlibdecompress(content))
            local filter = false
            local output = false
            for pass=1,7 do
                local xstart = xstart[pass]
                local xstep  = xstep[pass]
                local ystart = ystart[pass]
                local ystep  = ystep[pass]
                local nx     = idiv(xsize + xstep - xstart - 1,xstep)
                local ny     = idiv(ysize + ystep - ystart - 1,ystep)
                if nx > 0 and ny > 0 then
                    local input, filter
                    if parts then
                        local nxx = ceil(nx*parts/8)
                        input, filter = decodestrip(content,nxx,ny,slice)
                        input, filter = expand(input,nx,ny,parts,nxx,factor,filter)
                    else
                        input, filter = decodestrip(content,nx,ny,slice)
                    end
                    output = transpose(xsize,ysize,slice,pass,input,output,filter)
                end
             -- if pass == 3 then
             --     break -- still looks ok, could be nice for a preroll
             -- end
            end
            return output, parts and 8 or false
        end
    end

    -- 1 (palette used), 2 (color used), and 4 (alpha channel used)

    -- paeth:
    --
    -- p  = a + b - c
    -- pa = abs(p - a) => a + b - c - a => b - c
    -- pb = abs(p - b) => a + b - c - b => a - c
    -- pc = abs(p - c) => a + b - c - c => a + b - c - c => a - c + b - c => pa + pb

    local function full(t,k) local v = "\xFF" t[k] = v return v end

    local function expandvector(transparent)
        local s = openstring(transparent)
        local n = #transparent
        local r = { }
        for i=0,n-1 do
            r[i] = readstring(s,1) -- readchar
        end
        setmetatableindex(r,full)
        return r
    end

    local function createmask_l(content,palette,transparent,xsize,ysize,colordepth,colorspace)
        if palette then
            local r    = expandvector(transparent)
            local size = xsize*ysize
            local len  = ceil(xsize*colordepth/8) + 1
            local o    = newoutput(xsize*ysize)
            local u    = setmetatableindex(zero)
            content    = zlibdecompress(content)
            content    = openstring(content)
            for i=0,ysize-1 do
                local t = readbytetable(content,len)
                local k = i * xsize
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
                        k = k + 1 ; o[k] = r[v]
                    end
                elseif colordepth == 4 then
                    for j=2,len do
                        local v = t[j]
                        k = k + 1 ; o[k] = r[extract4(v,4)]
                        k = k + 1 ; o[k] = r[extract4(v,0)]
                    end
                elseif colordepth == 2 then
                    for j=2,len do
                        local v = t[j]
                        k = k + 1 ; o[k] = r[extract2(v,6)]
                        k = k + 1 ; o[k] = r[extract2(v,4)]
                        k = k + 1 ; o[k] = r[extract2(v,2)]
                        k = k + 1 ; o[k] = r[extract2(v,0)]
                    end
                else
                    for j=2,len do
                        local v = t[j]
                        k = k + 1 ; o[k] = r[extract1(v,7)]
                        k = k + 1 ; o[k] = r[extract1(v,6)]
                        k = k + 1 ; o[k] = r[extract1(v,5)]
                        k = k + 1 ; o[k] = r[extract1(v,4)]
                        k = k + 1 ; o[k] = r[extract1(v,3)]
                        k = k + 1 ; o[k] = r[extract1(v,2)]
                        k = k + 1 ; o[k] = r[extract1(v,1)]
                        k = k + 1 ; o[k] = r[extract1(v,0)]
                    end
                end
                u = t
            end
            return concat(o,"",1,size)
        end
    end

    local function createmask_c(content,palette,transparent,xsize,ysize,colordepth,colorspace)
        if palette then
            local r    = expandvector(transparent)
            local size = xsize*ysize
            local len  = ceil(xsize*colordepth/8)
            local o    = newoutput(size)
            content    = zlibdecompress(content)
            content    = pngapplyfilter(content,len,ysize,1) -- nostrip (saves copy)
            content    = openstring(content)
            for i=0,ysize-1 do
                local t = readbytetable(content,len)
                local k = i * xsize
                if colordepth == 8 then
                    for j=1,len do
                        local v = t[j]
                        k = k + 1 ; o[k] = r[v]
                    end
                elseif colordepth == 4 then
                    for j=1,len do
                        local v = t[j]
                        k = k + 1 ; o[k] = r[extract4(v,4)]
                        k = k + 1 ; o[k] = r[extract4(v,0)]
                    end
                elseif colordepth == 2 then
                    for j=1,len do
                        local v = t[j]
                        k = k + 1 ; o[k] = r[extract2(v,6)]
                        k = k + 1 ; o[k] = r[extract2(v,4)]
                        k = k + 1 ; o[k] = r[extract2(v,2)]
                        k = k + 1 ; o[k] = r[extract2(v,0)]
                    end
                else
                    for j=1,len do
                        local v = t[j]
                        k = k + 1 ; o[k] = r[extract1(v,7)]
                        k = k + 1 ; o[k] = r[extract1(v,6)]
                        k = k + 1 ; o[k] = r[extract1(v,5)]
                        k = k + 1 ; o[k] = r[extract1(v,4)]
                        k = k + 1 ; o[k] = r[extract1(v,3)]
                        k = k + 1 ; o[k] = r[extract1(v,2)]
                        k = k + 1 ; o[k] = r[extract1(v,1)]
                        k = k + 1 ; o[k] = r[extract1(v,0)]
                    end
                end
            end
            return concat(o,"",1,size)
        end
    end

    local function switch(v)
        if v then
            filtermask  = filtermask_l
            decodemask  = decodemask_l
            decodestrip = decodestrip_l
            transpose   = transpose_l
            expand      = expand_l
            createmask  = createmask_l
        else
            filtermask  = filtermask_c
            decodemask  = decodemask_c
            decodestrip = decodestrip_c
            transpose   = transpose_c
            expand      = expand_c
            createmask  = createmask_c
        end
    end

    if pngapplyfilter then
        switch(false)
        directives.register("graphics.png.purelua",switch)
    else
        switch(true)
    end

    local alwaysdecode = false

 -- directives.register("graphics.png.decode", function(v)
 --     alwaysdecode = v
 -- end)

    function injectors.png(specification)
-- inspect(specification)
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
        local pngfile = io.open(filename,"rb") -- todo: in-mem too
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
            report_png("you'd better use a version > 1.2")
            return
         -- decode = true
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
                if not (colordepth == 8 or colordepth == 16) then
                    report_png("mask can't be split from the image")
                    return
                end -- get rid of bpp:
                content, mask = filtermask(r,xsize,ysize,colordepth,colorspace,false)
            else
                content = convert(r) -- can be in deinterlace if needed
            end
            content = zlibcompress(content,3)
            decode  = true
        elseif mask then
            if not (colordepth == 8 or colordepth == 16) then
                report_png("mask can't be split from the image")
                return
            end
            content = zlibdecompress(content)
            content, mask = decodemask(content,xsize,ysize,colordepth,colorspace)
            content = zlibcompress(content,3)
            decode  = true -- we don't copy the filter byte
        elseif transparent then
            -- in test suite
            if palette then
                mask = createmask(content,palette,transparent,xsize,ysize,colordepth,colorspace)
            else
                pallette = false
            end
        elseif decode then
            -- this one needs checking
            local bytes = analyze(colordepth,colorspace)
            if bytes then
                content = zlibdecompress(content)
                content = applyfilter(content,xsize,ysize,bytes)
                content = zlibcompress(content,3)
            else
                return
            end
        else
         -- print("PASS ON")
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
        if specification.colorref then
            xobject.ColorSpace = pdfreference(specification.colorref)
        end
        return createimage {
            bbox      = { 0, 0, specification.width/xsize, specification.height/ysize }, -- mandate
            transform = specification.transform,
            nolength  = true,
            nobbox    = true,
            notype    = true,
            stream    = content,
            attr      = xobject(),
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

-- local function validcompression(data)
--     local d  = utilities.streams.openstring(data)
--     local b1 = utilities.streams.readbyte(d)
--     local b2 = utilities.streams.readbyte(d)
--     print(b1,b2)
--     if (b1 * 256 + b2) % 31 ~= 0 then
--         return false, "no zlib compressed file"
--     end
--     local method = band(b1,15)
--     if method ~= 8 then
--         return false, "method 8 expected"
--     end
--     local detail = band(rshift(b1,4),15)
--     if detail > 7 then
--         return false, "window 32 expected"
--     end
--     local preset = band(rshift(b2,5),1)
--     if preset ~= 0 then
--         return false, "unexpected preset dictionary"
--     end
--     return true
-- end
