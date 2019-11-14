    if not modules then modules = { } end modules ['grph-img'] = {
    version   = 1.001,
    comment   = "companion to grph-inc.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- The jpg identification and inclusion code is based on the code in \LUATEX\ but as we
-- use \LUA\ we can do it a bit cleaner. We can also use some helpers for reading from
-- file. We could make it even more lean and mean. When all works out ok I will clean
-- up this code a bit as we can divert more from luatex.

local lower, strip = string.lower, string.strip
local round = math.round
local concat = table.concat
local suffixonly = file.suffix

local newreader         = io.newreader
local setmetatableindex = table.setmetatableindex
local setmetatablecall  = table.setmetatablecall

local graphics       = graphics or { }
local identifiers    = { }
graphics.identifiers = identifiers

do

    local colorspaces = {
        [1] = 1, -- gray
        [3] = 2, -- rgb
        [4] = 3, -- cmyk
    }

    local tags = {
        [0xC0] = { name = "SOF0",                    }, -- baseline DCT
        [0xC1] = { name = "SOF1",                    }, -- extended sequential DCT
        [0xC2] = { name = "SOF2",                    }, -- progressive DCT
        [0xC3] = { name = "SOF3",  supported = false }, -- lossless (sequential)

        [0xC5] = { name = "SOF5",  supported = false }, -- differential sequential DCT
        [0xC6] = { name = "SOF6",  supported = false }, -- differential progressive DCT
        [0xC7] = { name = "SOF7",  supported = false }, -- differential lossless (sequential)

        [0xC8] = { name = "JPG",                     }, -- reserved for JPEG extensions
        [0xC9] = { name = "SOF9",                    }, -- extended sequential DCT
        [0xCA] = { name = "SOF10", supported = false }, -- progressive DCT
        [0xCB] = { name = "SOF11", supported = false }, -- lossless (sequential)

        [0xCD] = { name = "SOF13", supported = false }, -- differential sequential DCT
        [0xCE] = { name = "SOF14", supported = false }, -- differential progressive DCT
        [0xCF] = { name = "SOF15", supported = false }, -- differential lossless (sequential)

        [0xC4] = { name = "DHT"                      }, -- define Huffman table(s)

        [0xCC] = { name = "DAC"                      }, -- define arithmetic conditioning table

        [0xD0] = { name = "RST0", zerolength = true }, -- restart
        [0xD1] = { name = "RST1", zerolength = true }, -- restart
        [0xD2] = { name = "RST2", zerolength = true }, -- restart
        [0xD3] = { name = "RST3", zerolength = true }, -- restart
        [0xD4] = { name = "RST4", zerolength = true }, -- restart
        [0xD5] = { name = "RST5", zerolength = true }, -- restart
        [0xD6] = { name = "RST6", zerolength = true }, -- restart
        [0xD7] = { name = "RST7", zerolength = true }, -- restart

        [0xD8] = { name = "SOI",  zerolength = true }, -- start of image
        [0xD9] = { name = "EOI",  zerolength = true }, -- end of image
        [0xDA] = { name = "SOS"                     }, -- start of scan
        [0xDB] = { name = "DQT"                     }, -- define quantization tables
        [0xDC] = { name = "DNL"                     }, -- define number of lines
        [0xDD] = { name = "DRI"                     }, -- define restart interval
        [0xDE] = { name = "DHP"                     }, -- define hierarchical progression
        [0xDF] = { name = "EXP"                     }, -- expand reference image(s)

        [0xE0] = { name = "APP0"                    }, -- application marker, used for JFIF
        [0xE1] = { name = "APP1"                    }, -- application marker
        [0xE2] = { name = "APP2"                    }, -- application marker
        [0xE3] = { name = "APP3"                    }, -- application marker
        [0xE4] = { name = "APP4"                    }, -- application marker
        [0xE5] = { name = "APP5"                    }, -- application marker
        [0xE6] = { name = "APP6"                    }, -- application marker
        [0xE7] = { name = "APP7"                    }, -- application marker
        [0xE8] = { name = "APP8"                    }, -- application marker
        [0xE9] = { name = "APP9"                    }, -- application marker
        [0xEA] = { name = "APP10"                   }, -- application marker
        [0xEB] = { name = "APP11"                   }, -- application marker
        [0xEC] = { name = "APP12"                   }, -- application marker
        [0xED] = { name = "APP13"                   }, -- application marker
        [0xEE] = { name = "APP14"                   }, -- application marker, used by Adobe
        [0xEF] = { name = "APP15"                   }, -- application marker

        [0xF0] = { name = "JPG0"                    }, -- reserved for JPEG extensions
        [0xFD] = { name = "JPG13"                   }, -- reserved for JPEG extensions
        [0xFE] = { name = "COM"                     }, -- comment

        [0x01] = { name = "TEM",  zerolength = true }, -- temporary use
    }

    -- More can be found in http://www.exif.org/Exif2-2.PDF but basically we have
    -- good old tiff tags here.

    local function read_APP1_Exif(f, xres, yres, orientation) -- untested
        local position     = false
        local littleendian = false
        -- endian II|MM
        while true do
            position = f:getposition()
            local b  = f:readbyte()
            if b == 0 then
                -- next one
            elseif b == 0x4D and f:readbyte() == 0x4D then -- M
                -- big endian
                break
            elseif b == 0x49 and f:readbyte() == 0x49 then -- I
                -- little endian
                littleendian = true
                break
            else
                -- warning "bad exif data"
                return xres, yres, orientation
            end
        end
        -- version
        local version = littleendian and f:readcardinal2le() or f:readcardinal2()
        if version ~= 42 then
            return xres, yres, orientation
        end
        -- offset to records
        local offset = littleendian and f:readcardinal4le() or f:readcardinal4()
        if not offset then
            return xres, yres, orientation
        end
        f:setposition(position + offset)
        local entries = littleendian and f:readcardinal2le() or f:readcardinal2()
        if not entries or entries == 0 then
            return xres, yres, orientation
        end
        local x_res, y_res, x_res_ms, y_res_ms, x_temp, y_temp
        local res_unit, res_unit_ms
        for i=1,entries do
            local tag    = littleendian and f:readcardinal2le() or f:readcardinal2()
            local kind   = littleendian and f:readcardinal2le() or f:readcardinal2()
            local size   = littleendian and f:readcardinal4le() or f:readcardinal4()
            local value  = 0
            local num    = 0
            local den    = 0
            if kind == 1 or kind == 7 then -- byte | undefined
                value = f:readbyte()
                f:skip(3)
            elseif kind == 3 or kind == 8 then -- (un)signed short
                value = littleendian and f:readcardinal2le() or f:readcardinal2()
                f:skip(2)
            elseif kind == 4 or kind == 9 then -- (un)signed long
                value = littleendian and f:readcardinal4le() or f:readcardinal4()
            elseif kind == 5 or kind == 10 then -- (s)rational
                local offset = littleendian and f:readcardinal4le() or f:readcardinal4()
                local saved  = f:getposition()
                f:setposition(position+offset)
                num = littleendian and f:readcardinal4le() or f:readcardinal4()
                den = littleendian and f:readcardinal4le() or f:readcardinal4()
                f:setposition(saved)
            else -- 2 -- ascii
                f:skip(4)
            end
            if tag == 274 then         -- orientation
                orientation = value
            elseif tag == 282 then     -- x resolution
                if den ~= 0 then
                    x_res = num/den
                end
            elseif tag == 283 then     -- y resolution
                if den ~= 0 then
                    y_res = num/den
                end
            elseif tag == 296 then     -- resolution unit
                if value == 2 then
                    res_unit = 1
                elseif value == 3 then
                    res_unit = 2.54
                end
            elseif tag == 0x5110 then  -- pixel unit
                res_unit_ms = value == 1
            elseif tag == 0x5111 then  -- x pixels per unit
                x_res_ms = value
            elseif tag == 0x5112 then  -- y pixels per unit
                y_res_ms = value
            end
        end
        if x_res and y_res and res_unit and res_unit > 0 then
            x_temp = round(x_res * res_unit)
            y_temp = round(y_res * res_unit)
        elseif x_res_ms and y_res_ms and res_unit_ms then
            x_temp = round(x_res_ms * 0.0254) -- in meters
            y_temp = round(y_res_ms * 0.0254) -- in meters
        end
        if x_temp and a_temp and x_temp > 0 and y_temp > 0 then
            if (x_temp ~= x_res or y_temp ~=  y_res) and x_res ~= 0 and y_res ~= 0 then
                -- exif resolution differs from already found resolution
            elseif x_temp == 1 or y_temp == 1 then
                -- exif resolution is kind of weird
            else
                return x_temp, y_temp, orientation
            end
        end
        return round(xres), round(yres), orientation
    end

    function identifiers.jpg(filename,method)
        local specification = {
            filename = filename,
            filetype = "jpg",
        }
        if not filename or filename == "" then
            specification.error = "invalid filename"
            return specification -- error
        end
        local f = newreader(filename,method)
        if not f then
            specification.error = "unable to open file"
            return specification -- error
        end
        specification.xres        = 0
        specification.yres        = 0
        specification.orientation = 1
        specification.totalpages  = 1
        specification.pagenum     = 1
        specification.length      = 0
        local banner = f:readcardinal2()
        if banner ~= 0xFFD8 then
            specification.error = "no jpeg file"
            return specification -- error
        end
        local xres         = 0
        local yres         = 0
        local orientation  = 1
        local okay         = false
        local filesize     = f:getsize() -- seek end
     -- local majorversion = pdfmajorversion and pdfmajorversion() or 1
     -- local minorversion = pdfminorversion and pdfminorversion() or 7
        while f:getposition() < filesize do
            local b = f:readbyte()
            if not b then
                break
            elseif b ~= 0xFF then
                if not okay then
                    -- or check for size
                    specification.error = "incomplete file"
                end
                break
            end
            local category  = f:readbyte()
            local position  = f:getposition()
            local length    = 0
            local tagdata   = tags[category]
            if not tagdata then
                specification.error = "invalid tag"
                break
            elseif tagdata.supported == false then
                specification.error = "unsupported " .. tagdata.comment
                break
            end
            local name = tagdata.name
            if name == "SOF0" or name == "SOF1" or name == "SOF2" then
                --
                -- It makes no sense to support pdf < 1.3 so we now just omit this
                -- test. There is no need to polute the code with useless tests.
                --
             -- if majorversion == 1 and minorversion <= 2 then
             --     specification.error = "no progressive DCT in PDF <= 1.2"
             --     break
             -- end
                length = f:readcardinal2()
                specification.colordepth = f:readcardinal()
                specification.ysize      = f:readcardinal2()
                specification.xsize      = f:readcardinal2()
                specification.colorspace = colorspaces[f:readcardinal()]
                if not specification.colorspace then
                    specification.error = "unsupported color space"
                    break
                end
                okay = true
            elseif name == "APP0" then
                length = f:readcardinal2()
                if length > 6 then
                    local format = f:readstring(5)
                    if format  == "JFIF\000" then
                        f:skip(2)
                        units = f:readcardinal()
                        xres  = f:readcardinal2()
                        yres  = f:readcardinal2()
                        if units == 1 then
                            -- pixels per inch
                            if xres == 1 or yres == 1 then
                                -- warning
                            end
                        elseif units == 2 then
                            -- pixels per cm */
                            xres = xres * 2.54
                            yres = yres * 2.54
                        else
                            xres = 0
                            yres = 0
                        end
                    end
                end
            elseif name == "APP1" then
                length = f:readcardinal2()
                if length > 7 then
                    local format = f:readstring(5)
                    if format == "Exif\000" then
                        xres, yres, orientation = read_APP1_Exif(f,xres,yres,orientation)
                    end
                end
            elseif not tagdata.zerolength then
                length = f:readcardinal2()
            end
            if length > 0 then
                f:setposition(position+length)
            end
        end
        f:close()
        if not okay then
            specification.error = specification.error or "invalid file"
        elseif not specification.error then
            if xres == 0 and yres ~= 0 then
                xres = yres
            end
            if yres == 0 and xres ~= 0 then
                yres = xres
            end
        end
        specification.xres        = xres
        specification.yres        = yres
        specification.orientation = orientation
        specification.length      = filesize
        return specification
    end

end

do

    local function read_boxhdr(specification,f)
        local size = f:readcardinal4()
        local kind = f:readstring(4)
        if kind then
            kind = strip(lower(kind))
        else
            kind = ""
        end
        if size == 1 then
            size = f:readcardinal4() * 0xFFFF0000 + f:readcardinal4()
        end
        if size == 0 and kind ~= "jp2c" then  -- move this
            specification.error = "invalid size"
        end
        return kind, size
    end

    local function scan_ihdr(specification,f)
        specification.ysize = f:readcardinal4()
        specification.xsize = f:readcardinal4()
        f:skip(2) -- nc
        specification.colordepth = f:readcardinal() + 1
        f:skip(3) -- c unkc ipr
    end

    local function scan_resc_resd(specification,f)
        local vr_n = f:readcardinal2()
        local vr_d = f:readcardinal2()
        local hr_n = f:readcardinal2()
        local hr_d = f:readcardinal2()
        local vr_e = f:readcardinal()
        local hr_e = f:readcardinal()
        specification.xres = math.round((hr_n / hr_d) * math.exp(hr_e * math.log(10.0)) * 0.0254)
        specification.yres = math.round((vr_n / vr_d) * math.exp(vr_e * math.log(10.0)) * 0.0254)
    end

    local function scan_res(specification,f,last)
        local pos = f:getposition()
        while true do
            local kind, size = read_boxhdr(specification,f)
            pos = pos + size
            if kind == "resc" then
                if specification.xres == 0 and specification.yres == 0 then
                    scan_resc_resd(specification,f)
                    if f:getposition() ~= pos then
                        specification.error = "invalid resc"
                        return
                    end
                end
            elseif tpos == "resd" then
                scan_resc_resd(specification,f)
                if f:getposition() ~= pos then
                    specification.error = "invalid resd"
                    return
                end
            elseif pos > last then
                specification.error = "invalid res"
                return
            elseif pos == last then
                break
            end
            if specification.error then
                break
            end
            f:setposition(pos)
        end
    end

    local function scan_jp2h(specification,f,last)
        local okay = false
        local pos  = f:getposition()
        while true do
            local kind, size = read_boxhdr(specification,f)
            pos = pos + size
            if kind == "ihdr" then
                scan_ihdr(specification,f)
                if f:getposition() ~= pos then
                    specification.error = "invalid ihdr"
                    return false
                end
                okay = true
            elseif kind == "res" then
                scan_res(specification,f,pos)
            elseif pos > last then
                specification.error = "invalid jp2h"
                return false
            elseif pos == last then
                break
            end
            if specification.error then
                break
            end
            f:setposition(pos)
        end
        return okay
    end

    function identifiers.jp2(filename,method)
        local specification = {
            filename = filename,
            filetype = "jp2",
        }
        if not filename or filename == "" then
            specification.error = "invalid filename"
            return specification -- error
        end
        local f = newreader(filename,method)
        if not f then
            specification.error = "unable to open file"
            return specification -- error
        end
        specification.xres        = 0
        specification.yres        = 0
        specification.orientation = 1
        specification.totalpages  = 1
        specification.pagenum     = 1
        specification.length      = 0
        local xres         = 0
        local yres         = 0
        local orientation  = 1
        local okay         = false
        local filesize     = f:getsize() -- seek end
        --
        local pos = 0
        --  signature
        local kind, size = read_boxhdr(specification,f)
        pos = pos + size
        f:setposition(pos)
        -- filetype
        local kind, size = read_boxhdr(specification,f)
        if kind ~= "ftyp" then
            specification.error = "missing ftyp box"
            return specification
        end
        pos = pos + size
        f:setposition(pos)
        while not okay do
            local kind, size = read_boxhdr(specification,f)
            pos = pos + size
            if kind == "jp2h" then
               okay = scan_jp2h(specification,f,pos)
            elseif kind == "jp2c" and not okay then
                specification.error = "no ihdr box found"
                return specification
            end
            f:setposition(pos)
        end
        --
        f:close()
        if not okay then
            specification.error = "invalid file"
        elseif not specification.error then
            if xres == 0 and yres ~= 0 then
                xres = yres
            end
            if yres == 0 and xres ~= 0 then
                yres = xres
            end
        end
        specification.xres        = xres
        specification.yres        = yres
        specification.orientation = orientation
        specification.length      = filesize
        return specification
    end

end

do

    -- 0 = gray               "image b"
    -- 2 = rgb                "image c"
    -- 3 = palette            "image c" + "image i"
    -- 4 = gray + alpha       "image b"
    -- 6 = rgb + alpha        "image c"

    -- for i=1,length/3 do
    --     palette[i] = f:readstring3)
    -- end

    local function grab(t,f,once)
        if once then
            for i=1,#t do
                local l = t[i]
                f:setposition(l.offset)
                t[i] = f:readstring(l.length)
            end
            local data = concat(t)
            -- t wiped in caller
            return data
        else
            local data = { }
            for i=1,#t do
                local l = t[i]
                f:setposition(l.offset)
                data[i] = f:readstring(l.length)
            end
            return concat(data)
        end
    end

    function identifiers.png(filename,method)
        local specification = {
            filename = filename,
            filetype = "png",
        }
        if not filename or filename == "" then
            specification.error = "invalid filename"
            return specification -- error
        end
        local f = newreader(filename,method)
        if not f then
            specification.error = "unable to open file"
            return specification -- error
        end
        specification.xres        = 0
        specification.yres        = 0
        specification.orientation = 1
        specification.totalpages  = 1
        specification.pagenum     = 1
        specification.offset      = 0
        specification.length      = 0
        local filesize = f:getsize() -- seek end
        local tables   = { }
        local banner   = f:readstring(8)
        if banner ~= "\137PNG\013\010\026\010" then
            specification.error = "no png file"
            return specification -- error
        end
        while true do
            local position = f:getposition()
            if position >= filesize then
                break
            end
            local length = f:readcardinal4()
            if not length then
                break
            end
            local kind = f:readstring(4)
            if kind then
                kind = lower(kind)
            else
                break
            end
            if kind == "ihdr" then -- metadata
                specification.xsize       = f:readcardinal4()
                specification.ysize       = f:readcardinal4()
                specification.colordepth  = f:readcardinal()
                specification.colorspace  = f:readcardinal()
                specification.compression = f:readcardinal()
                specification.filter      = f:readcardinal()
                specification.interlace   = f:readcardinal()
                tables[kind] = true
            elseif kind == "iend" then
                tables[kind] = true
                break
            elseif kind == "phys" then
                local x = f:readcardinal4()
                local y = f:readcardinal4()
                local u = f:readcardinal()
                if u == 1 then -- meters
                 -- x = round(0.0254 * x)
                 -- y = round(0.0254 * y)
                end
                specification.xres = x
                specification.yres = y
                tables[kind] = true
            elseif kind == "idat" or kind == "plte" or kind == "gama" or kind == "trns" then
                local t = tables[kind]
                if not t then
                    t = setmetatablecall(grab)
                    tables[kind] = t
                end
                t[#t+1] = {
                    offset = f:getposition(),
                    length = length,
                }
            else
                tables[kind] = true
            end
            f:setposition(position+length+12) -- #size #kind #crc
        end
        f:close()
        specification.tables = tables
        return specification
    end

end

do

    local function gray(t,k)
        local v = 0
        t[k] = v
        return v
    end

    local function rgb(t,k)
        local v = { 0, 0, 0 }
        t[k] = v
        return v
    end

    local function cmyk(t,k)
        local v = { 0, 0, 0, 0 }
        t[k] = v
        return v
    end

    function identifiers.bitmap(specification)
        local xsize      = specification.xsize or 0
        local ysize      = specification.ysize or 0
        local width      = specification.width or xsize * 65536
        local height     = specification.height or ysize * 65536
        local colordepth = specification.colordepth or 1 -- 1 .. 2
        local colorspace = specification.colorspace or 1 -- 1 .. 3
        local pixel      = false
        local data       = specification.data
        local mask       = specification.mask
        local index = specification.index
        if colorspace == 1 or colorspace == "gray" then
            pixel      = gray
            colorspace = 1
        elseif colorspace == 2 or colorspace == "rgb"  then
            pixel      = rgb
            colorspace = 2
        elseif colorspace == 3 or colorspace == "cmyk"  then
            pixel      = cmyk
            colorspace = 3
        else
            return
        end
        if colordepth == 8 then
            colordepth = 1
        elseif colordepth == 16 then
            colordepth = 2
        end
        if colordepth > 1 then
            -- not yet
            return
        end
        if data then
            -- assume correct data
        else
            data = { }
            for i=1,ysize do
                data[i] = setmetatableindex(pixel)
            end
        end
        if mask == true then
            mask = { }
            for i=1,ysize do
                mask[i] = setmetatableindex(gray)
            end
        end
        if index then
            index = setmetatableindex(pixel)
        end
        local specification = {
            xsize      = xsize,
            ysize      = ysize,
            width      = width,
            height     = height,
            colordepth = colordepth,
            colorspace = colorspace,
            data       = data,
            mask       = mask,
            index      = index,
        }
        return specification
    end

end

function graphics.identify(filename,filetype)
    local identify = filetype and identifiers[filetype]
    if identify then
        return identify(filename)
    end
    local identify = identifiers[suffixonly(filename)]
    if identify then
        identify = identify(filename)
    else
        identify = {
            filename = filename,
            filetype = filetype,
            error    = "identification failed",
        }
    end
 -- inspect(identify)
    return identify
end

-- inspect(identifiers.jpg("t:/sources/hacker.jpg"))
-- inspect(identifiers.png("t:/sources/mill.png"))
