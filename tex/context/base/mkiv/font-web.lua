if not modules then modules = { } end modules ['font-otr'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- Okay, compressing fonts this way is rather simple but one might wonder what the gain
-- is in this time of 4K youtube movies and most of the web pages wasting space and
-- bandwidth on advertisements. For version 2 we can use "woff2_decompress" from google
-- and in a tex environment one can as well store the ttf/otf files in the tex tree. So,
-- eventually we might even remove this code when version 1 is obsolete.

local ioopen         = io.open
local replacesuffix  = file.replacesuffix

local readers        = fonts and fonts.handlers.otf.readers

local streamreader   = readers and readers.streamreader or utilities.files
local streamwriter   = readers and readers.streamwriter or utilities.files

local readstring     = streamreader.readstring
local readcardinal2  = streamreader.readcardinal2
local readcardinal4  = streamreader.readcardinal4
local getsize        = streamreader.getsize
local setposition    = streamreader.setposition
local getposition    = streamreader.getposition

local writestring    = streamwriter.writestring
local writecardinal4 = streamwriter.writecardinal4
local writecardinal2 = streamwriter.writecardinal2
local writebyte      = streamwriter.writebyte

local decompress     = zlib.decompress

directives.register("fonts.streamreader",function()

    streamreader  = utilities.streams

    readstring    = streamreader.readstring
    readcardinal2 = streamreader.readcardinal2
    readcardinal4 = streamreader.readcardinal4
    getsize       = streamreader.getsize
    setposition   = streamreader.setposition
    getposition   = streamreader.getposition

end)

local infotags = {
    ["os/2"] = true,
    ["head"] = true,
    ["maxp"] = true,
    ["hhea"] = true,
    ["hmtx"] = true,
    ["post"] = true,
    ["cmap"] = true,
}

local report = logs.reporter("fonts","woff")

local runner = sandbox.registerrunner {
    name     = "woff2otf",
    method   = "execute",
    program  = "woff2_decompress",
    template = "%inputfile% %outputfile%",
    reporter = report,
    checkers = {
        inputfile  = "readable",
        outputfile = "writable",
    }
}

local function woff2otf(inpname,outname,infoonly)

    local outname = outname or replacesuffix(inpname,"otf")
    local inp     = ioopen(inpname,"rb")

    if not inp then
        report("invalid input file %a",inpname)
        return
    end

    local signature = readstring(inp,4)

    if not (signature == "wOFF" or signature == "wOF2") then
        inp:close()
        report("invalid signature in %a",inpname)
        return
    end

    local flavor = readstring(inp,4)

    if not (flavor == "OTTO" or flavor == "true" or flavor == "\0\1\0\0") then
        inp:close()
        report("unsupported flavor %a in %a",flavor,inpname)
        return
    end

    if signature == "wOF2" then
        inp:close()
        if false then
            if runner then
                runner {
                    inputfile  = inpname,
                    outputfile = outname,
                }
            end
            return outname, flavor
        else
            report("skipping version 2 file %a",inpname)
            return
        end
    end

    local out = ioopen(outname,"wb")

    if not out then
        inp:close()
        report("invalid output file %a",outname)
        return
    end

    local header = {
        signature      = signature,
        flavor         = flavor,
        length         = readcardinal4(inp),
        numtables      = readcardinal2(inp),
        reserved       = readcardinal2(inp),
        totalsfntsize  = readcardinal4(inp),
        majorversion   = readcardinal2(inp),
        minorversion   = readcardinal2(inp),
        metaoffset     = readcardinal4(inp),
        metalength     = readcardinal4(inp),
        metaoriglength = readcardinal4(inp),
        privoffset     = readcardinal4(inp),
        privlength     = readcardinal4(inp),
    }

    local entries = { }

    for i=1,header.numtables do
        local entry = {
            tag        = readstring   (inp,4),
            offset     = readcardinal4(inp),
            compressed = readcardinal4(inp),
            size       = readcardinal4(inp),
            checksum   = readcardinal4(inp),
        }
        if not infoonly or infotags[lower(entry.tag)] then
            entries[#entries+1] = entry
        end
    end

    local nofentries    = #entries
    local entryselector = 0  -- we don't need these
    local searchrange   = 0  -- we don't need these
    local rangeshift    = 0  -- we don't need these

    writestring   (out,flavor)
    writecardinal2(out,nofentries)
    writecardinal2(out,entryselector)
    writecardinal2(out,searchrange)
    writecardinal2(out,rangeshift)

    local offset  = 12 + nofentries * 16
    local offsets = { }

    for i=1,nofentries do
        local entry = entries[i]
        local size  = entry.size
        writestring(out,entry.tag)
        writecardinal4(out,entry.checksum)
        writecardinal4(out,offset) -- the new offset
        writecardinal4(out,size)
        offsets[i] = offset
        offset = offset + size
        local p = 4 - offset % 4
        if p > 0 then
            offset = offset + p
        end
    end

    for i=1,nofentries do
        local entry  = entries[i]
        local offset = offsets[i]
        local size   = entry.size
        setposition(inp,entry.offset+1)
        local data = readstring(inp,entry.compressed)
        if #data ~= size then
            data = decompress(data)
        end
        setposition(out,offset+1)
        writestring(out,data)
        local p = 4 - offset + size % 4
        if p > 0 then
            for i=1,p do
                writebyte(out,0)
            end
        end
    end

    inp:close()
    out:close()

    return outname, flavor

end

if readers then
    readers.woff2otf = woff2otf
else
    return woff2otf
end
