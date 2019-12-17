    if not modules then modules = { } end modules ['font-tpk'] = {
    version   = 1.001,
    comment   = "companion to font-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- The bitmap loader is more or less derived from the luatex version (taco)
-- which is derived from pdftex (thanh) who uses code from dvips (thomas)
-- adapted by piet ... etc. The tfm and vf readers are also derived from
-- luatex. All do things a bit more luaish and errors are of course mine.

local next = next
local extract, band, lshift, rshift = bit32.extract, bit32.band, bit32.lshift, bit32.rshift
local idiv = number.idiv
local char = string.char
local concat, insert, remove, copy = table.concat, table.insert, table.remove, table.copy
local tobitstring = number.tobitstring
local formatters = string.formatters
local round = math.round

local streams       = utilities.streams
local openstream    = streams.open
local streamsize    = streams.size
local readcardinal1 = streams.readcardinal1
local readcardinal2 = streams.readcardinal2
local readcardinal3 = streams.readcardinal3
local readcardinal4 = streams.readcardinal4
local readinteger1  = streams.readinteger1
local readinteger2  = streams.readinteger2
local readinteger3  = streams.readinteger3
local readinteger4  = streams.readinteger4
local readbyte      = streams.readbyte
local readbytes     = streams.readbytes
local readstring    = streams.readstring
local skipbytes     = streams.skipbytes
local getposition   = streams.getposition
local setposition   = streams.setposition

if not fonts then fonts = { handlers = { tfm = { } } } end

local handlers = fonts.handlers
local tfm      = handlers.tfm or { }
handlers.tfm   = tfm
local readers  = tfm.readers or { }
tfm.readers    = readers

tfm.version      = 1.005
tfm.cache        = containers.define("fonts", "tfm", tfm.version, true)

-- Performance is no real issue here so I didn't optimize too much. After
-- all, these files are small and we mostly use opentype or type1 fonts.

do

    local function readbitmap(glyph,s,flagbyte)

        local inputbyte   = 0
        local bitweight   = 0
        local dynf        = 0
        local remainder   = 0
        local realfunc    = nil
        local repeatcount = 0

        local function getnyb() -- can be inlined
            if bitweight == 0 then
                bitweight = 16
                inputbyte = readbyte(s)
                return extract(inputbyte,4,4)
            else
                bitweight = 0
                return band(inputbyte,15)
            end
        end

        local function getbit() -- can be inlined
            bitweight = rshift(bitweight,1)
            if bitweight == 0 then -- actually we can check for 1
                inputbyte = readbyte(s)
                bitweight = 128
            end
            return band(inputbyte,bitweight)
        end

        local function pkpackednum()
            local i = getnyb(s)
            if i == 0 then
                repeat
                    j = getnyb()
                    i = i + 1
                until (j ~= 0)
                if i > 3 then
                    return handlehuge(i,j)
                else
                    for i=1,i do
                        j = j * 16 + getnyb()
                    end
                    return j - 15 + (13 - dynf) * 16 + dynf
                end
            elseif i <= dynf then
                return i
            elseif i < 14 then
                return (i - dynf - 1) * 16 + getnyb() + dynf + 1
            elseif i == 14 then
                repeatcount = pkpackednum()
            else
                repeatcount = 1
            end
            return realfunc()
        end

        local function rest()
            if remainder < 0 then
                remainder = -remainder
                return 0
            elseif remainder > 4000 then
                remainder = 4000 - remainder
                return 4000
            elseif remainder > 0 then
                local i = remainder
                remainder = 0
                realfunc  = pkpackednum
                return i
            else
             -- error = "pk issue that shouldn't happen"
                return 0
            end
        end

        local function handlehuge(i,j)
            while i ~= 0 do
                j = lshift(j,4) + getnyb()
    --             j = extract(j,8,4) + getnyb()
                i = i - 1
            end
            remainder = j - 15 + (13 - dynf) * 16 + dynf
            realfunc  = rest
            return rest()
        end

        local gpower = { [0] =
                0,   1,    3,    7,   15,   31,    63,   127,
              255, 511, 1023, 2047, 4095, 8191, 16383, 32767,
            65535
        }

        local raster = { }
        local r      = 0
        glyph.stream = raster

        local xsize      = glyph.xsize
        local ysize      = glyph.ysize
        local word       = 0
        local wordweight = 0
        local wordwidth  = idiv(xsize + 15,16)
        local rowsleft   = 0
        local turnon     = band(flagbyte,8) == 8 and true or false
        local hbit       = 0
        local count      = 0
        --
        realfunc         = pkpackednum
        dynf             = idiv(flagbyte,16)
        --
        if dynf == 14 then
            bitweight = 0
            for i=1,ysize do
                word       = 0
                wordweight = 32768
                for j=1,xsize do
                    if getbit() ~= 0 then
                        word = word + wordweight
                    end
                    wordweight = rshift(wordweight,1)
                    if wordweight == 0 then
                        r          = r + 1
                        raster[r]  = word
                        word       = 0
                        wordweight = 32768
                    end
                end
                if wordweight ~= 32768 then
                    r         = r + 1
                    raster[r] = word
                end
            end
        else
            rowsleft    = ysize
            hbit        = xsize
            repeatcount = 0
            wordweight  = 16
            word        = 0
            bitweight   = 0
            while rowsleft > 0 do
                count = realfunc()
                while count ~= 0 do
                    if count < wordweight and count < hbit then
                        if turnon then
                            word = word + gpower[wordweight] - gpower[wordweight - count]
                        end
                        hbit       = hbit - count
                        wordweight = wordweight - count
                        count      = 0
                    elseif count >= hbit and hbit <= wordweight then
                        if turnon then
                            word = word + gpower[wordweight] - gpower[wordweight - hbit]
                        end
                        r          = r + 1
                        raster[r]  = word
                        for i=1,repeatcount*wordwidth do
                            r          = r + 1
                            raster[r]  = raster[r - wordwidth]
                        end
                        rowsleft    = rowsleft - repeatcount - 1
                        repeatcount = 0
                        word        = 0
                        wordweight  = 16
                        count       = count - hbit
                        hbit        = xsize
                    else
                        if turnon then
                            word = word + gpower[wordweight]
                        end
                        r          = r + 1
                        raster[r]  = word
                        word       = 0
                        count      = count - wordweight
                        hbit       = hbit - wordweight
                        wordweight = 16
                    end
                end
                turnon = not turnon
            end
            if rowsleft ~= 0 or hbit ~= xsize then
                print("ERROR",rowsleft,hbit,xsize)
                -- error = "error while unpacking, more bits than required"
            end
        end

    end

    function readers.showpk(glyph)
        local xsize  = glyph.xsize
        local ysize  = glyph.ysize
        local stream = glyph.stream
        local result = { }
        local rr     = { }
        local r      = 0
        local s      = 0
        local cw     = idiv(xsize+ 7, 8)
        local rw     = idiv(xsize+15,16)
        local extra  = 2 * rw == cw
        local b
        for y=1,ysize do
            r = 0
            for x=1,rw-1 do
                s = s + 1 ; b = stream[s]
                r = r + 1 ; rr[r] = tobitstring(b,16,16)
            end
                s = s + 1 ; b = stream[s]
            if extra then
                r = r + 1 ; rr[r] = tobitstring(b,16,16)
            else
                r = r + 1 ; rr[r] = tobitstring(extract(b,8+(8-cw),cw),cw,cw)
            end
            result[y] = concat(rr)
        end
        return concat(result,"\n")
    end

    local template = formatters [ [[
%.3N 0 %i %i %i %i d1
q
%i 0 0 %i %i %i cm
BI
  /W %i
  /H %i
  /IM true
  /BPC 1
  /D [1 0]
ID %t
EI
Q]] ]

    function readers.pktopdf(glyph,data,factor)
        local width   = data.width * factor
        local xsize   = glyph.xsize or 0
        local ysize   = glyph.ysize or 0
        local xoffset = glyph.xoffset or 0
        local yoffset = glyph.yoffset or 0
        local stream  = glyph.stream

        local dpi     = 1
        local newdpi  = 1

        local xdpi    = dpi * xsize  / newdpi
        local ydpi    = dpi * ysize  / newdpi

        local llx     = - xoffset
        local lly     = yoffset - ysize + 1
        local urx     = llx + xsize + 1
        local ury     = lly + ysize

        local result  = { }
        local r       = 0
        local s       = 0
        local cw      = idiv(xsize+ 7, 8)
        local rw      = idiv(xsize+15,16)
        local extra   = 2 * rw == cw
        local b
        for y=1,ysize do
            for x=1,rw-1 do
                s = s + 1 ; b = stream[s]
                r = r + 1 ; result[r] = char(extract(b,8,8),extract(b,0,8))
            end
            s = s + 1 ; b = stream[s]
            if extra then
                r = r + 1 ; result[r] = char(extract(b,8,8),extract(b,0,8))
            else
                r = r + 1 ; result[r] = char(extract(b,8,8))
            end
        end
        return template(width,llx,lly,urx,ury,xdpi,ydpi,llx,lly,xsize,ysize,result), width
    end

    function readers.loadpk(filename)
        local s          = openstream(filename)
        local preamble   = readcardinal1(s)
        local version    = readcardinal1(s)
        local comment    = readstring(s,readcardinal1(s))
        local designsize = readcardinal4(s)
        local checksum   = readcardinal4(s)
        local hppp       = readcardinal4(s)
        local vppp       = readcardinal4(s)
        if preamble ~= 247 or version ~= 89 or not vppp then
            return { error = "invalid preamble" }
        end
        local glyphs = { }
        local data   = {
            designsize = designsize,
            comment    = comment,
            hppp       = hppp,
            vppp       = vppp,
            glyphs     = glyphs,
        }
        while true do
            local flagbyte = readcardinal1(s)
            if flagbyte < 240 then
                local c = band(flagbyte,7)
                local length, index, width, pixels, xsize, ysize, xoffset, yoffset
                if c >= 0 and c <= 3 then
                    length  = band(flagbyte,7) * 256 + readcardinal1(s) - 3
                    index   = readcardinal1(s)
                    width   = readinteger3(s)
                    pixels  = readcardinal1(s)
                    xsize   = readcardinal1(s)
                    ysize   = readcardinal1(s)
                    xoffset = readcardinal1(s)
                    yoffset = readcardinal1(s)
                    if xoffset > 127 then
                        xoffset = xoffset - 256
                    end
                    if yoffset > 127 then
                        yoffset = yoffset - 256
                    end
                elseif c >= 4 and c <= 6 then
                    length  = band(flagbyte,3) * 65536 + readcardinal1(s) * 256 + readcardinal1(s) - 4
                    index   = readcardinal1(s)
                    width   = readinteger3(s)
                    pixels  = readcardinal2(s)
                    xsize   = readcardinal2(s)
                    ysize   = readcardinal2(s)
                    xoffset = readcardinal2(s)
                    yoffset = readcardinal2(s)
                else -- 7
                    length  = readcardinal4(s) - 9
                    index   = readcardinal4(s)
                    width   = readinteger4(s)
                    pixels  = readcardinal4(s)
                              readcardinal4(s)
                    xsize   = readcardinal4(s)
                    ysize   = readcardinal4(s)
                    xoffset = readcardinal4(s)
                    yoffset = readcardinal4(s)
                end
                local glyph = {
                    index   = index,
                    width   = width,
                    pixels  = pixels,
                    xsize   = xsize,
                    ysize   = ysize,
                    xoffset = xoffset,
                    yoffset = yoffset,
                }
                if length <= 0 then
                    data.error = "bad packet"
                    return data
                end
                readbitmap(glyph,s,flagbyte)
                glyphs[index] = glyph
            elseif flagbyte == 240 then
                -- k[1] x[k]
                skipbytes(s,readcardinal1(s))
            elseif flagbyte == 241 then
                -- k[2] x[k]
                skipbytes(s,readcardinal2(s)*2)
            elseif flagbyte == 242 then
                -- k[3] x[k]
                skipbytes(s,readcardinal3(s)*3)
            elseif flagbyte == 243 then
                -- k[4] x[k]
                skipbytes(s,readcardinal4(s)*4) -- readinteger4
            elseif flagbyte == 244 then
                -- y[4]
                skipbytes(s,4)
            elseif flagbyte == 245 then
                break
            elseif flagbyte == 246 then
                -- nop
            else
                data.error = "unknown pk command"
                break
            end
        end
        return data
    end

end

do

    local leftboundary  = -1
    local rightboundary = -2
    local boundarychar  = 65536

    function readers.loadtfm(filename)
        local data
        --
        local function someerror(m)
            if not data then
                data = { }
            end
            data.error = m or "fatal error"
            return data
        end
        --
        local s = openstream(filename)
        if not s then
            return someerror()
        end
        --
        local wide       = false
        local header     = 0
        local max        = 0
        local size       = streamsize(s)
        local glyphs     = table.setmetatableindex(function(t,k)
            local v = {
                -- we default because boundary chars have no dimension s
                width  = 0,
                height = 0,
                depth  = 0,
                italic = 0,
            }
            t[k] = v
            return v
        end)
        local parameters = { }
        local direction  = 0
        --
        local lf, lh, bc, ec, nw, nh, nd, ni, nl, nk, ne, np
        --
        lf = readcardinal2(s)
        if lf ~= 0 then
            header = 6
            max    = 255
            wide   = false
            lh = readcardinal2(s)
            bc = readcardinal2(s)
            ec = readcardinal2(s)
            nw = readcardinal2(s)
            nh = readcardinal2(s)
            nd = readcardinal2(s)
            ni = readcardinal2(s)
            nl = readcardinal2(s)
            nk = readcardinal2(s)
            ne = readcardinal2(s)
            np = readcardinal2(s)
        else
            header = 14
            max    = 65535
            wide   = readcardinal4(s) == 0
            if not wide then
                return someerror("invalid format")
            end
            lf = readcardinal4(s)
            lh = readcardinal4(s)
            bc = readcardinal4(s)
            ec = readcardinal4(s)
            nw = readcardinal4(s)
            nh = readcardinal4(s)
            nd = readcardinal4(s)
            ni = readcardinal4(s)
            nl = readcardinal4(s)
            nk = readcardinal4(s)
            ne = readcardinal4(s)
            np = readcardinal4(s)
            direction = readcardinal4(s)
        end
        if (bc > ec + 1) or (ec > max) then
            return someerror("file is too small")
        end
        if bc > max then
            bc, ec = 1, 0
        end
        local nlw  = (wide and 2 or 1) * nl
        local neew = (wide and 2 or 1) * ne
        local ncw  = (wide and 2 or 1) * (ec - bc + 1)
        if lf ~= (header + lh + ncw + nw + nh + nd + ni + nlw + nk + neew + np) then
            return someerror("file is too small")
        end
        if nw == 0 or nh == 0 or nd == 0 or ni == 0 then
            return someerror("no glyphs")
        end
        if lf * 4 > size then
            return someerror("file is too small")
        end
        local slh = lh
        if lh < 2 then
            return someerror("file is too small")
        end
        local checksum   = readcardinal4(s)
        local designsize = readcardinal2(s)
        designsize = designsize * 256 +        readcardinal1(s)
        designsize = designsize *  16 + rshift(readcardinal1(s),4)
        if designsize < 0xFFFF then
            return someerror("weird designsize")
        end
        --
        local alpha =  16
        local z     = designsize
        while z >= 040000000 do
            z = rshift(z,1)
            alpha = alpha + alpha
        end
        local beta = idiv(256,alpha)
        alpha = alpha * z
        --
        local function readscaled()
            local a, b, c, d = readbytes(s,4)
            local n = idiv(rshift(rshift(d*z,8)+c*z,8)+b*z,beta)
            if a == 0 then
                return n
            elseif a == 255 then
                return n - alpha
            else
                return 0
            end
        end
        --
        local function readunscaled()
            local a, b, c, d = readbytes(s,4)
            if a > 127 then
                a = a - 256
            end
            return a * 0xFFFFF + b * 0xFFF + c * 0xF + rshift(d,4)
        end
        --
        while lh > 2 do -- can be one-liner
            skipbytes(s,4)
            lh = lh - 1
        end
        local saved = getposition(s)
        setposition(s,(header + slh + ncw) * 4 + 1)
        local widths  = { } for i=0,nw-1 do widths [i] = readscaled() end
        local heights = { } for i=0,nh-1 do heights[i] = readscaled() end
        local depths  = { } for i=0,nd-1 do depths [i] = readscaled() end
        local italics = { } for i=0,ni-1 do italics[i] = readscaled() end
        if widths[0] ~= 0 or heights[0] ~= 0 or depths[0] ~= 0 then
            return someerror("invalid dimensions")
        end
        --
        local blabel = nl
        local bchar  = boundarychar
        --
        local ligatures = { }
        if nl > 0 then
            for i=0,nl-1 do
                local a, b, c, d = readbytes(s,4)
                ligatures[i] = {
                    skip = a,
                    nxt  = b,
                    op   = c,
                    rem  = d,
                }
                if a > 128 then
                    if 256 * c + d >= nl then
                        return someerror("invalid ligature table")
                    end
                    if a == 255 and i == 0 then
                        bchar = b
                    end
                else
                    if c < 128 then
                       -- whatever
                    elseif 256 * (c - 128) + d >= nk then
                        return someerror("invalid ligature table")
                    end
                    if (a < 128) and (i - 0 + a + 1 >= nl) then
                        return someerror("invalid ligature table")
                    end
                end
                if a == 255 then
                    blabel = 256 * c + d
                end
            end
        end
        local allkerns = { }
        for i=0,nk-1 do
            allkerns[i] = readscaled()
        end
        local extensibles = { }
        for i=0,ne-1 do
            extensibles[i] = wide and {
                top = readcardinal2(s),
                bot = readcardinal2(s),
                mid = readcardinal2(s),
                rep = readcardinal2(s),
            } or {
                top = readcardinal1(s),
                bot = readcardinal1(s),
                mid = readcardinal1(s),
                rep = readcardinal1(s),
            }
        end
        for i=1,np do
            if i == 1 then
                parameters[i] = readunscaled()
            else
                parameters[i] = readscaled()
            end
        end
        for i=1,7 do
            if not parameters[i] then
                parameters[i] = 0
            end
        end
        --
        setposition(s,saved)
        local extras = false
        if blabel ~= nl then
            local k = blabel
            while true do
                local l    = ligatures[k]
                local skip = l.skip
                if skip <= 128 then
                 -- if l.op >= 128 then
                 --     extras = true -- kern
                 -- else
                        extras = true -- ligature
                 -- end
                end
                if skip == 0 then
                    k = k + 1
                else
                    if skip >= 128 then
                       break
                    end
                    k = k + skip + 1
                end
            end
        end
        if extras then
            local ligas = { }
            local kerns = { }
            local k     = blabel
            while true do
                local l    = ligatures[k]
                local skip = l.skip
                if skip <= 128 then
                    local nxt = l.nxt
                    local op  = l.op
                    local rem = l.rem
                    if op >= 128 then
                        kerns[nxt] = allkerns[256 * (op - 128) + rem]
                    else
                        ligas[nxt] = { type = op * 2 + 1, char = rem }
                    end
                end
                if skip == 0 then
                    k = k + 1
                else
                    if skip >= 128 then
                        break;
                    end
                    k = k + skip + 1
                end
            end
            if next(kerns) then
                local glyph     = glyphs[leftboundary]
                glyph.kerns     = kerns
                glyph.remainder = 0
            end
            if next(ligas) then
                local glyph     = glyphs[leftboundary]
                glyph.ligatures = ligas
                glyph.remainder = 0
            end
        end
        for i=bc,ec do
            local glyph, width, height, depth, italic, tag, remainder
            if wide then
                width     = readcardinal2(s)
                height    = readcardinal1(s)
                depth     = readcardinal1(s)
                italic    = readcardinal1(s)
                tag       = readcardinal1(s)
                remainder = readcardinal2(s)
            else
                width     = readcardinal1(s)
                height    = readcardinal1(s)
                depth     = extract(height,0,4)
                height    = extract(height,4,4)
                italic    = readcardinal1(s)
                tag       = extract(italic,0,2)
                italic    = extract(italic,2,6)
                remainder = readcardinal1(s)
            end
            if width == 0 then
                -- nothing
            else
                if width >= nw or height >= nh or depth >= nd or italic >= ni then
                    return someerror("invalid dimension index")
                end
                local extensible, nextinsize
                if tag == 0 then
                    -- nothing special
                else
                    local r = remainder
                    if tag == 1 then
                        if r >= nl then
                            return someerror("invalid ligature index")
                        end
                    elseif tag == 2 then
                        if r < bc or r > ec then
                            return someerror("invalid chain index")
                        end
                        while r < i do
                            local g = glyphs[r]
                            if g.tag ~= list_tag then
                                break
                            end
                            r = g.remainder
                        end
                        if r == i then
                            return someerror("cycles in chain")
                        end
                        nextinsize = r
                    elseif tag == 3 then
                        if r >= ne then
                            return someerror("bad extensible")
                        end
                        extensible = extensibles[r] -- remainder ?
                        remainder  = 0
                    end
                end
                glyphs[i] = {
                    width      = widths [width],
                    height     = heights[height],
                    depth      = depths [depth],
                    italic     = italics[italic],
                    tag        = tag,
                 -- index      = i,
                    remainder  = remainder,
                    extensible = extensible,
                    next       = nextinsize,
                }
            end
        end
        for i=bc,ec do
            local glyph  = glyphs[i]
            if glyph.tag == 1 then
                -- ligature
                local k = glyph.remainder
                local l = ligatures[k]
                if l.skip > 128 then
                    k = 256 * l.op + l.rem
                end
                local ligas = { }
                local kerns = { }
                while true do
                    local l    = ligatures[k]
                    local skip = l.skip
                    if skip <= 128 then
                        local nxt = l.nxt
                        local op  = l.op
                        local rem = l.rem
                        if op >= 128 then
                            local kern = allkerns[256 * (op - 128) + rem]
                            if nxt == bchar then
                                kerns[rightboundary] = kern
                            end
                            kerns[nxt] = kern
                        else
                            local ligature = { type = op * 2 + 1, char = rem }
                            if nxt == bchar then
                                ligas[rightboundary] = ligature
                            end
                            ligas[nxt] = ligature -- shared
                        end
                    end
                    if skip == 0 then
                       k = k + 1
                    else
                        if skip >= 128 then
                            break
                        end
                        k = k + skip + 1
                    end
                end
                if next(kerns)then
                    glyph.kerns     = kerns
                    glyph.remainder = 0
                end
                if next(ligas) then
                    glyph.ligatures = ligas
                    glyph.remainder = 0
                end
            end
        end
        --
        if bchar ~= boundarychar then
           glyphs[rightboundary] = copy(glyphs[bchar])
        end
        --
     -- for k, v in next, glyphs do
     --     v.tag       = nil
     --     v.remainder = nil
     -- end
        --
        return {
            name           = file.nameonly(filename),
            fontarea       = file.pathpart(filename),
            glyphs         = glyphs,
            parameters     = parameters,
            designsize     = designsize,
            size           = designsize,
            direction      = direction,
         -- checksum       = checksum,
         -- embedding      = "unknown",
         -- encodingbytes  = 0,
         -- extend         = 1000,
         -- slant          = 0,
         -- squeeze        = 0,
         -- format         = "unknown",
         -- identity       = "unknown",
         -- mode           = 0,
         -- streamprovider = 0,
         -- tounicode      = 0,
         -- type           = "unknown",
         -- units_per_em   = 0,
         -- used           = false,
         -- width          = 0,
         -- writingmode    = "unknown",
        }
    end

end

do

    local push = { "push" }
    local push = { "pop" }

    local w, x, y, z, f
    local stack
    local s, result, r
    local alpha, beta, z

    local function scaled1()
        local a = readbytes(s,1)
        if a == 0 then
            return 0
        elseif a == 255 then
            return - alpha
        else
            return 0 -- error
        end
    end

    local function scaled2()
        local a, b = readbytes(s,2)
        local sw = idiv(b*z,beta)
        if a == 0 then
            return sw
        elseif a == 255 then
            return sw - alpha
        else
            return 0 -- error
        end
    end

    local function scaled3()
        local a, b, c = readbytes(s,3)
        local sw = idiv(rshift(c*z,8)+b*z,beta)
        if a == 0 then
            return sw
        elseif a == 255 then
            return sw - alpha
        else
            return 0 -- error
        end
    end

    local function scaled4()
        local a, b, c, d = readbytes(s,4)
        local sw = idiv( rshift(rshift(d*z,8)+(c*z),8)+b*z,beta)
        if a == 0 then
            return sw
        elseif a == 255 then
            return sw - alpha
        else
            return 0 -- error
        end
    end

    local function dummy()
    end

    local actions = {

        [128] = function() r = r + 1 result[r] = { "slot", f or 1, readcardinal1(s) } p = p + 1 end,
        [129] = function() r = r + 1 result[r] = { "slot", f or 1, readcardinal2(s) } p = p + 2 end,
        [130] = function() r = r + 1 result[r] = { "slot", f or 1, readcardinal3(s) } p = p + 3 end,
        [131] = function() r = r + 1 result[r] = { "slot", f or 1, readcardinal4(s) } p = p + 4 end,

        [132] = function()
            r = r + 1
            result[r] = { "rule", scaled4(), scaled4() }
            p = p + 8
        end,

        [133] = function()
                    r = r + 1 result[r] = push
                    r = r + 1 result[r] = { "slot", f or 1, readcardinal1(s) }
                    r = r + 1 result[r] = pop
                    p = p + 1
                end,
        [134] = function()
                    r = r + 1 result[r] = push
                    r = r + 1 result[r] = { "slot", f or 1, readcardinal2(s) }
                    r = r + 1 result[r] = pop
                    p = p + 2
                end,
        [135] = function()
                    r = r + 1 result[r] = push
                    r = r + 1 result[r] = { "slot", f or 1, readcardinal2(s) }
                    r = r + 1 result[r] = pop
                    p = p + 3
                end,
        [136] = function()
                    r = r + 1 result[r] = push
                    r = r + 1 result[r] = { "slot", f or 1, readcardinal4(s) }
                    r = r + 1 result[r] = pop
                    p = p + 4
                end,

        [137] = function()
                    r = r + 1 result[r] = push
                    r = r + 1 result[r] = { "rule", scaled4(), scaled4() }
                    r = r + 1 result[r] = pop
                    p = p + 8
                end,

        [138] = dummy, -- nop
        [139] = dummy, -- bop
        [140] = dummy, -- eop

        [141] = function()
                    insert(stack, { w, x, y, z })
                    r = r + 1
                    result[r] = push
                end,
        [142] = function()
                    local t = remove(stack)
                    if t then
                        w, x, y, z = t[1], t[2], t[3], t[4]
                        r = r + 1
                        result[r] = pop
                    end
                end,

        [143] = function() r = r + 1 result[r] = { "right", scaled1() } p = p + 1 end,
        [144] = function() r = r + 1 result[r] = { "right", scaled2() } p = p + 2 end,
        [145] = function() r = r + 1 result[r] = { "right", scaled3() } p = p + 3 end,
        [146] = function() r = r + 1 result[r] = { "right", scaled4() } p = p + 4 end,

        [148] = function() w = scaled1() r = r + 1 result[r] = { "right", w } p = p + 1 end,
        [149] = function() w = scaled2() r = r + 1 result[r] = { "right", w } p = p + 2 end,
        [150] = function() w = scaled3() r = r + 1 result[r] = { "right", w } p = p + 3 end,
        [151] = function() w = scaled4() r = r + 1 result[r] = { "right", w } p = p + 4 end,

        [153] = function() x = scaled1() r = r + 1 result[r] = { "right", x } p = p + 1 end,
        [154] = function() x = scaled2() r = r + 1 result[r] = { "right", x } p = p + 2 end,
        [155] = function() x = scaled3() r = r + 1 result[r] = { "right", x } p = p + 3 end,
        [156] = function() x = scaled4() r = r + 1 result[r] = { "right", x } p = p + 4 end,

        [157] = function() r = r + 1 result[r] = { "down", scaled1() } p = p + 1 end,
        [158] = function() r = r + 1 result[r] = { "down", scaled2() } p = p + 2 end,
        [159] = function() r = r + 1 result[r] = { "down", scaled3() } p = p + 3 end,
        [160] = function() r = r + 1 result[r] = { "down", scaled4() } p = p + 4 end,

        [162] = function() y = scaled1() r = r + 1 result[r] = { "down", y } p = p + 1 end,
        [163] = function() y = scaled2() r = r + 1 result[r] = { "down", y } p = p + 2 end,
        [164] = function() y = scaled3() r = r + 1 result[r] = { "down", y } p = p + 3 end,
        [165] = function() y = scaled3() r = r + 1 result[r] = { "down", y } p = p + 4 end,

        [167] = function() z = scaled1() r = r + 1 ; result[r] = { "down", z } p = p + 4 end,
        [168] = function() z = scaled2() r = r + 1 ; result[r] = { "down", z } p = p + 4 end,
        [169] = function() z = scaled3() r = r + 1 ; result[r] = { "down", z } p = p + 4 end,
        [170] = function() z = scaled4() r = r + 1 ; result[r] = { "down", z } p = p + 4 end,

        [147] = function() r = r + 1 result[r] = { "right", w } end,
        [152] = function() r = r + 1 result[r] = { "right", x } end,
        [161] = function() r = r + 1 result[r] = { "down",  y } end,
        [166] = function() r = r + 1 result[r] = { "down",  z } end,

        [235] = function() f = readcardinal1(s) p = p + 1 end,
        [236] = function() f = readcardinal2(s) p = p + 3 end,
        [237] = function() f = readcardinal3(s) p = p + 3 end,
        [238] = function() f = readcardinal4(s) p = p + 4 end,

        [239] = function() local n = readcardinal1(s) r = r + 1 result[r] = { "special", readstring(s,n) } p = p + 1 + n end,
        [240] = function() local n = readcardinal2(s) r = r + 1 result[r] = { "special", readstring(s,n) } p = p + 2 + n end,
        [241] = function() local n = readcardinal3(s) r = r + 1 result[r] = { "special", readstring(s,n) } p = p + 3 + n end,
        [242] = function() local n = readcardinal4(s) r = r + 1 result[r] = { "special", readstring(s,n) } p = p + 4 + n end,

        [250] = function() local n = readcardinal1(s) r = r + 1 result[r] = { "pdf", readstring(s,n) } p = p + 1 + n end,
        [251] = function() local n = readcardinal2(s) r = r + 1 result[r] = { "pdf", readstring(s,n) } p = p + 2 + n end,
        [252] = function() local n = readcardinal3(s) r = r + 1 result[r] = { "pdf", readstring(s,n) } p = p + 3 + n end,
        [253] = function() local n = readcardinal4(s) r = r + 1 result[r] = { "pdf", readstring(s,n) } p = p + 4 + n end,

    }

    table.setmetatableindex(actions,function(t,cmd)
        local v
        if cmd >= 0 and cmd <= 127 then
            v = function()
                if f == 0 then
                    f = 1
                end
                r = r + 1 ; result[r] = { "slot", f, cmd }
            end
        elseif cmd >= 171 and cmd <= 234 then
            cmd = cmd - 170
            v = function()
                r = r + 1 ; result[r] = { "font", cmd }
            end
        else
            v = dummy
        end
        t[cmd] = v
        return v
    end)

    function readers.loadvf(filename,data)
        --
        local function someerror(m)
            if not data then
                data = { }
            end
            data.error = m or "fatal error"
            return data
        end
        --
        s = openstream(filename)
        if not s then
            return someerror()
        end
        --
        local cmd = readcardinal1(s)
        if cmd ~= 247 then
            return someerror("bad preamble")
        end
        cmd = readcardinal1(s)
        if cmd ~= 202 then
            return someerror("bad version")
        end
        local header     = readstring(s,readcardinal1(s))
        local checksum   = readcardinal4(s)
        local designsize = idiv(readcardinal4(s),16)
        local fonts      = data and data.fonts  or { }
        local glyphs     = data and data.glyphs or { }
        --
        alpha =  16
        z     = designsize
        while z >= 040000000 do
            z = rshift(z,1)
            alpha = alpha + alpha
        end
        beta  = idiv(256,alpha)
        alpha = alpha * z
        --
        cmd = readcardinal1(s)
        while true do
            local n
            if cmd == 243 then
                n = readcardinal1(s) + 1
            elseif cmd == 244 then
                n = readcardinal2(s) + 1
            elseif cmd == 245 then
                n = readcardinal3(s) + 1
            elseif cmd == 246 then
                n = readcardinal4(s) + 1
            else
                break
            end
            local checksum   = skipbytes(s,4)
            local size       = scaled4()
            local designsize = idiv(readcardinal4(s),16)
            local pathlen    = readcardinal1(s)
            local namelen    = readcardinal1(s)
            local path       = readstring(s,pathlen)
            local name       = readstring(s,namelen)
            fonts[n] = { path = path, name = name, size = size }
            cmd = readcardinal1(s)
        end
        local index = 0
        while cmd and cmd <= 242 do
            local width    = 0
            local length   = 0
            local checksum = 0
            if cmd == 242 then
                length   = readcardinal4(s)
                checksum = readcardinal4(s)
                width    = readcardinal4(s)
            else
                length   = cmd
                checksum = readcardinal1(s)
                width    = readcardinal3(s)
            end
            w, x, y, z, f = 0, 0, 0, 0, false
            stack, result, r, p = { }, { }, 0, 0
            while p < length do
                local cmd = readcardinal1(s)
                p = p + 1
                actions[cmd]()
            end
            local glyph = glyphs[index]
            if glyph then
                glyph.width    = width
                glyph.commands = result
            else
                glyphs[index] = {
                    width    = width,
                    commands = result,
                }
            end
            index = index + 1
            if #stack > 0 then
                -- error: more pushes than pops
            end
            if packet_length ~= 0 then
                -- error: invalid packet length
            end
            cmd = readcardinal1(s)
        end
        if readcardinal1(s) ~= 248 then
            -- error: no post
        end
        s, result, r = nil, nil, nil
        if data then
            data.glyphs = data.glyphs or glyphs
            data.fonts  = data.fonts  or fonts
            return data
        else
            return {
                name       = file.nameonly(filename),
                fontarea   = file.pathpart(filename),
                glyphs     = glyphs,
                designsize = designsize,
                header     = header,
                fonts      = fonts,
            }
        end
    end

    -- the replacement loader (not sparse):

    function readers.loadtfmvf(tfmname,size)
        local vfname  = file.addsuffix(file.nameonly(tfmfile),"vf")
        local tfmfile = tfmname
        local vffile  = resolvers.findbinfile(vfname,"ovf")
        if tfmfile and tfmfile ~= "" then
            if size < 0 then
                size = idiv(65536 * -size,100)
            end
            local data = readers.loadtfm(tfmfile)
            if data.error then
                return data
            end
            if vffile and vffile ~= "" then
                data = readers.loadvf(vffile,data)
                if data.error then
                    return data
                end
            end
            local designsize = data.designsize
            local glyphs     = data.glyphs
            local parameters = data.parameters
            local fonts      = data.fonts
            if size ~= designsize then
                local factor = size / designsize
                for index, glyph in next, glyphs do
                    if next(glyph) then
                        glyph.width  = round(factor*glyph.width)
                        glyph.height = round(factor*glyph.height)
                        glyph.depth  = round(factor*glyph.depth)
                        local italic = glyph.italic
                        if italic == 0 then
                            glyph.italic = nil
                        else
                            glyph.italic = round(factor*glyph.italic)
                        end
                        --
                        local kerns = glyph.kerns
                        if kerns then
                            for index, kern in next, kerns do
                                kerns[index] = round(factor*kern)
                            end
                        end
                        --
                        local commands = glyph.commands
                        if commands then
                            for i=1,#commands do
                                local c = commands[i]
                                local t = c[1]
                                if t == "down" or t == "right" then
                                    c[2] = round(factor*c[2])
                                elseif t == "rule" then
                                    c[2] = round(factor*c[2])
                                    c[3] = round(factor*c[3])
                                end
                            end
                        end
                    else
                        glyphs[index] = nil
                    end
                end
                for i=2,30 do
                    local p = parameters[i]
                    if p then
                        parameters[i] = round(factor*p)
                    else
                        break
                    end
                end
                if fonts then
                    for k, v in next, fonts do
                        v.size = round(factor*v.size)
                    end
                end
            else
                for index, glyph in next, glyphs do
                    if next(glyph) then
                        if glyph.italic == 0 then
                            glyph.italic = nil
                        end
                    else
                        glyphs[index] = nil
                    end
                end
            end
            --
            parameters.slant         = parameters[1]
            parameters.space         = parameters[2]
            parameters.space_stretch = parameters[3]
            parameters.space_shrink  = parameters[4]
            parameters.x_height      = parameters[5]
            parameters.quad          = parameters[6]
            parameters.extra_space   = parameters[7]
            --
            for i=1,7 do
                parameters[i] = nil -- so no danger for async
            end
            --
            data.characters = glyphs
            data.glyphs     = nil
            data.size       = size
            -- we assume type1 for now ... maybe the format should be unknown
            data.filename   = tfmfile -- file.replacesuffix(tfmfile,"pfb")
            data.format     = "unknown"
            --
            return data
        end
    end

end

-- inspect(readers.loadtfmvf(resolvers.findfile("mi-iwonari.tfm")))
-- inspect(readers.loadtfm(resolvers.findfile("texnansi-palatinonova-regular.tfm")))
-- inspect(readers.loadtfm(resolvers.findfile("cmex10.tfm")))
-- inspect(readers.loadtfm(resolvers.findfile("cmr10.tfm")))
-- local t = readers.loadtfmvf("texnansi-lte50019.tfm")
-- inspect(t)
