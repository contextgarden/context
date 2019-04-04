if not modules then modules = { } end modules ['lpdf-ini'] = {
    version   = 1.001,
    comment   = "companion to lpdf-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- vkgoeswild: Pink Floyd - Shine on You Crazy Diamond - piano cover

-- At some point I wanted to have access to the shapes so that we could use them in
-- metapost. So, after looking at the cff and ttf specifications, I decided to write
-- parsers. At somepoint we needed a cff parser anyway in order to calculate the
-- dimensions. Then variable fonts came around and a option was added to recreate
-- streams of operators and a logical next step was to do all inclusion that way. It
-- was only then that I found out that some of the juggling also happens in the the
-- backend, but spread over places, so I could have saved myself some time
-- deciphering the specifications. Anyway, here we go.

local next, type, unpack = next, type, unpack
local char, byte, gsub, sub, match, rep, gmatch = string.char, string.byte, string.gsub, string.sub, string.match, string.rep, string.gmatch
local formatters = string.formatters
local format = string.format
local concat, sortedhash, sort = table.concat, table.sortedhash, table.sort
local utfchar = utf.char
local random, round, max, abs, ceiling = math.random, math.round, math.max, math.abs, math.ceiling
local extract, lshift, rshift, band, bor = bit32.extract, bit32.lshift, bit32.rshift, bit32.band, bit32.bor
local idiv = number.idiv
local setmetatableindex = table.setmetatableindex

local pdfnull              = lpdf.null
local pdfdictionary        = lpdf.dictionary
local pdfarray             = lpdf.array
local pdfconstant          = lpdf.constant
local pdfstring            = lpdf.string
local pdfreference         = lpdf.reference
local pdfreserveobject     = lpdf.reserveobject
local pdfflushobject       = lpdf.flushobject
local pdfflushstreamobject = lpdf.flushstreamobject

local fontstreams          = fonts.hashes.streams

local report_fonts         = logs.reporter("backend","fonts")
local trace_fonts          = false
local trace_detail         = false

trackers.register("backend.pdf.fonts",function(v) trace_fonts = v end)

local readers = fonts.handlers.otf.readers
local getinfo = readers.getinfo

local setposition = utilities.files.setposition
local readstring  = utilities.files.readstring
local openfile    = utilities.files.open
local closefile   = utilities.files.close

-- needs checking: signed vs unsigned

local tocardinal1 = char

local function tocardinal2(n)
    return char(extract(n,8,8),extract(n,0,8))
end

local function tocardinal3(n)
    return char(extract(n,16,8),extract(n,8,8),extract(n,0,8))
end

local function tocardinal4(n)
    return char(extract(n,24,8),extract(n,16,8),extract(n,8,8),extract(n,0,8))
end

local function tointeger2(n)
    return char(extract(n,8,8),extract(n,0,8))
end

local function tointeger3(n)
    return char(extract(n,16,8),extract(n,8,8),extract(n,0,8))
end

local function tointeger4(n)
    return char(extract(n,24,8),extract(n,16,8),extract(n,8,8),extract(n,0,8))
end

local function tocardinal8(n)
    local l = idiv(n,0x100000000)
    local r = n % 0x100000000
    return char(extract(l,24,8),extract(l,16,8),extract(l,8,8),extract(l,0,8),
                extract(r,24,8),extract(r,16,8),extract(r,8,8),extract(r,0,8))
end

-- A couple of shared helpers.

local tounicodedictionary, widtharray, collectindices, subsetname, includecidset, tocidsetdictionary

do

    -- Because we supply tounicodes ourselves we only use bfchar mappings (as in the
    -- backend). In fact, we can now no longer pass the tounicodes to the frontend but
    -- pick them up from the descriptions.

    local f_mapping = formatters["<%04X> <%s>"]

    local tounicode = fonts.mappings.tounicode

local tounicode_template = [[
%%!PS-Adobe-3.0 Resource-CMap
%%%%DocumentNeededResources: ProcSet (CIDInit)
%%%%IncludeResource: ProcSet (CIDInit)
%%%%BeginResource: CMap (TeX-%s-0)
%%%%Title: (TeX-%s-0 TeX %s 0)|
%%%%Version: 1.000
%%%%EndComments
/CIDInit /ProcSet findresource begin
  12 dict begin
    begincmap
      /CIDSystemInfo
        << /Registry (TeX) /Ordering (%s) /Supplement 0 >>
      def
      /CMapName
        /TeX-Identity-%s
      def
      /CMapType
        2
      def
      1 begincodespacerange
        <0000> <FFFF>
      endcodespacerange
      %i beginbfchar

%s

      endbfchar
    endcmap
    CMapName currentdict /CMap defineresource pop
  end
end
%%%%EndResource
%%%%EOF]]

    tounicodedictionary = function(details,indices,maxindex,name)
        local mapping = { }
        local length  = 0
        if maxindex > 0 then
            for index=1,maxindex do
                local data = indices[index]
                if data then
                    length = length + 1
                    local unicode = data.unicode
                    if unicode then
                        unicode = tounicode(unicode)
                    else
                        unicode = "FFFD"
                    end
                    mapping[length] = f_mapping(index,unicode)
                end
            end
        end
        local name = gsub(name,"%+","-") -- like luatex does
        local blob = format(tounicode_template,name,name,name,name,name,length,concat(mapping,"\n"))
        return blob
    end

    widtharray = function(details,indices,maxindex,units)
        local widths = pdfarray()
        local length = 0
        local factor = 10000 / units
        if maxindex > 0 then
            local lastindex = -1
            local sublist   = nil
            for index=1,maxindex do
                local data = indices[index]
                if data then
                    local width = data.width -- hm, is inaccurate for cff, so take from elsewhere
                    if width then
                     -- width = round(width * 10000 / units) / 10
                        width = round(width * factor) / 10
                    else
                        width = 0
                    end
                    if index == lastindex + 1 then
                        sublist[#sublist+1] = width
                    else
                        if sublist then
                            length = length + 1
                            widths[length] = sublist
                        end
                        sublist = pdfarray { width }
                        length  = length + 1
                        widths[length] = index
                    end
                    lastindex = index
                end
            end
            length = length + 1
            widths[length] = sublist
        end
        return widths
    end

    collectindices = function(descriptions,indices)
        local minindex = 0xFFFF
        local maxindex = 0
        local reverse  = { }
        -- todo: already at definition time trigger copying streams
        -- and add extra indices ... first i need a good example of
        -- a clash
     -- for unicode, data in next, descriptions do
     --     local i = data.index or unicode
     --     if reverse[i] then
     --         print("CLASH")
     --     else
     --         reverse[i] = data
     --     end
     -- end
        for unicode, data in next, descriptions do
            reverse[data.index or unicode] = data
        end
        for index in next, indices do
            if index > maxindex then
                maxindex = index
            end
            if index < minindex then
                minindex = index
            end
            indices[index] = reverse[index]
        end
        if minindex > maxindex then
            minindex = maxindex
        end
        return indices, minindex, maxindex
    end

    includecidset = false

    tocidsetdictionary = function(indices,min,max)
        if includecidset then
            local b = { }
            local m = idiv(max+7,8)
            for i=0,max do
                b[i] = 0
            end
            for i=min,max do
                if indices[i] then
                    local bi = idiv(i,8)
                    local ni = i % 8
                    b[bi] = bor(b[bi],lshift(1,7-ni))
                end
            end
            b = char(unpack(b,0,#b))
            return pdfreference(pdfflushstreamobject(b))
        end
    end

    -- Actually we can use the same as we only embed once.

    -- subsetname = function(name)
    --     return "CONTEXT" .. name
    -- end

    local prefixes = { } -- todo: set fixed one

    subsetname = function(name)
        local prefix
        while true do
            prefix = utfchar(random(65,90),random(65,90),random(65,90),random(65,90),random(65,90),random(65,90))
            if not prefixes[prefix] then
                prefixes[prefix] = true
                break
            end
        end
        return prefix .. "+" .. name
    end

end

-- Map file mess.

local loadmapfile, loadmapline, getmapentry  do

    -- We only need to pick up the filename and optionally the enc file
    -- as we only use them for old school virtual math fonts. We might as
    -- we drop this completely.

    local find, match, splitlines = string.find, string.match, string.splitlines


    local mappings = { }

    loadmapline = function(n)
        local name, fullname, encfile, pfbfile = match(n,"(%S+)%s+(%S+).-<(.-%.enc).-<(.-%.pfb)")
        if name then
            mappings[name] = { fullname, encfile, pfbfile }
        end
    end

    loadmapfile = function(n)
        local okay, data = resolvers.loadbinfile(n,"map")
        if okay and data then
            data = splitlines(data)
            for i=1,#data do
                local d = data[i]
                if d ~= "" and not find(d,"^[#%%]") then
                    loadmapline(d)
                end
            end
        end
    end

    getmapentry = function(n)
        local n = file.nameonly(n)
        local m = mappings[n]
        if m then
            local encfile  = m[2]
            local encoding = fonts.encodings.load(encfile)
            if not encoding then
                return
            end
            local pfbfile = resolvers.find_file(m[3],"pfb")
            if not pfbfile or pfbfile == "" then
                return
            end
            return encoding, pfbfile, encfile
        end
    end

end

-- The three writers: opentype, truetype and type1.

local mainwriters  = { }

do

    -- advh = os2.ascender - os2.descender
    -- tsb  = default_advh - os2.ascender

    -- truetype has the following tables:

    -- head : mandate
    -- hhea : mandate
    -- vhea : mandate
    -- hmtx : mandate
    -- maxp : mandate
    -- glyf : mandate
    -- loca : mandate
    --
    -- cvt  : if needed (but we flatten)
    -- fpgm : if needed (but we flatten)
    -- prep : if needed (but we flatten)
    -- PCLT : if needed (but we flatten)
    --
    -- name : not needed for T2: backend does that
    -- post : not needed for T2: backend does that
    -- OS/2 : not needed for T2: backend does that
    -- cmap : not needed for T2: backend does that

    local streams       = utilities.streams
    local openstring    = streams.openstring
    local readcardinal2 = streams.readcardinal2
    ----- readcardinal4 = streams.readcardinal4

    local otfreaders    = fonts.handlers.otf.readers

    local function readcardinal4(f) -- this needs to be sorted out
        local a = readcardinal2(f)
        local b = readcardinal2(f)
        if a and b then
            return a * 0x10000 + b
        end
    end

    -- -- --

    local tablereaders  = { }
    local tablewriters  = { }
    local tablecreators = { }
    local tableloaders  = { }

    local openfontfile, closefontfile, makefontfile, makemetadata  do

        local details    = {
            details        = true,
            platformnames  = true,
            platformextras = true,
        }

        -- .022 sec on luatex manual, neglectable:

     -- local function checksum(data)
     --     local s = openstring(data)
     --     local n = 0
     --     local d = #data
     --     while true do
     --         local c = readcardinal4(s)
     --         if c then
     --             n = (n + c) % 0x100000000
     --         else
     --             break
     --         end
     --     end
     --     return n
     -- end

        local function checksum(data)
            local s = openstring(data)
            local n = 0
            local d = #data
            while true do
                local a = readcardinal2(s)
                local b = readcardinal2(s)
                if b then
                    n = (n + a * 0x10000 + b) % 0x100000000
                else
                    break
                end
            end
            return n
        end

        openfontfile = function(details)
            return {
                offset  = 0,
                order   = { },
                used    = { },
                details = details,
                streams = details.streams,
            }
        end

        closefontfile = function(fontfile)
            for k, v in next, fontfile do
                fontfile[k] = nil -- so it can be collected asap
            end
        end

        local metakeys = {
            "uniqueid", "version",
            "copyright", "license", "licenseurl",
            "manufacturer", "vendorurl",
            "family", "subfamily",
            "typographicfamily", "typographicsubfamily",
            "fullname", "postscriptname",
        }

    local template = [[
<?xpacket begin="﻿﻿" id="W5M0MpCehiHzreSzNTczkc9d"?>
  <x:xmpmeta xmlns:x="adobe:ns:meta/">
    <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
      <rdf:Description rdf:about="" xmlns:pdfx="http://ns.adobe.com/pdfx/1.3/">

%s

      </rdf:Description>
    </rdf:RDF>
  </x:xmpmeta>
<?xpacket end="w"?>]]

        makemetadata = function(fontfile)
            local names  = fontfile.streams.names
            local list   = { }
            local f_name = formatters["<pdfx:%s>%s</pdfx:%s>"]
            for i=1,#metakeys do
                local m = metakeys[i]
                local n = names[m]
                if n then
                    list[#list+1] = f_name(m,n,m)
                end
            end
            return format(template,concat(list,"\n"))
        end

        makefontfile = function(fontfile)
            local order = fontfile.order
            local used  = fontfile.used
            local count = 0
            for i=1,#order do
                local tag  = order[i]
                local data = fontfile[tag]
                if data and #data > 0 then
                    count = count + 1
                else
                    fontfile[tag] = false
                end
            end
            local offset = 12 + (count * 16)
            local headof = 0
            local list   = {
                "" -- placeholder
            }
            local i = 1
            local k = 0
            while i <= count do
                i = lshift(i,1)
                k = k + 1
            end
            local searchrange   = lshift(i,3)
            local entryselector = k - 1
            local rangeshift    = lshift(count,4) - lshift(i,3)
            local index  = {
                tocardinal4(0x00010000), -- tables.version
                tocardinal2(count),
                tocardinal2(searchrange),
                tocardinal2(entryselector),
                tocardinal2(rangeshift),
            }
            --
            local ni = #index
            local nl = #list
            for i=1,#order do
                local tag  = order[i]
                local data = fontfile[tag]
                if data then
                    local csum    = checksum(data)
                    local dlength = #data
                    local length  = idiv(dlength+3,4) * 4
                    local padding = length - dlength
                    nl = nl + 1 ; list[nl] = data
                    for i=1,padding do
                        nl = nl + 1 ; list[nl] = "\0"
                    end
                    if #tag == 3 then
                        tag = tag .. " "
                    end
                    ni = ni + 1 ; index[ni] = tag -- must be 4 chars
                    ni = ni + 1 ; index[ni] = tocardinal4(csum)
                    ni = ni + 1 ; index[ni] = tocardinal4(offset)
                    ni = ni + 1 ; index[ni] = tocardinal4(dlength)
                    used[i] = offset -- not used
                    if tag == "head" then
                        headof = offset
                    end
                    offset = offset + length
                end
            end
            list[1] = concat(index)
            local off = #list[1] + headof + 1 + 8
            list = concat(list)
            local csum = (0xB1B0AFBA - checksum(list)) % 0x100000000
            list = sub(list,1,off-1) .. tocardinal4(csum) .. sub(list,off+4,#list)
            return list
        end

        local function register(fontfile,name)
            local u = fontfile.used
            local o = fontfile.order
            if not u[name] then
                o[#o+1] = name
                u[name] = true
            end
        end

        local function create(fontfile,name)
            local t = { }
            fontfile[name] = t
            return t
        end

        local function write(fontfile,name)
            local t = fontfile[name]
            if not t then
                return
            end
            register(fontfile,name)
            if type(t) == "table" then
                if t[0] then
                    fontfile[name] = concat(t,"",0,#t)
                elseif #t > 0 then
                    fontfile[name] = concat(t)
                else
                    fontfile[name] = false
                end
            end
        end

        tablewriters.head = function(fontfile)
            register(fontfile,"head")
            local t = fontfile.streams.fontheader
            fontfile.head = concat {
                tocardinal4(t.version),
                tocardinal4(t.fontversionnumber),
                tocardinal4(t.checksum),
                tocardinal4(t.magic),
                tocardinal2(t.flags),
                tocardinal2(t.units),
                tocardinal8(t.created),
                tocardinal8(t.modified),
                tocardinal2(t.xmin),
                tocardinal2(t.ymin),
                tocardinal2(t.xmax),
                tocardinal2(t.ymax),
                tocardinal2(t.macstyle),
                tocardinal2(t.smallpixels),
                tocardinal2(t.directionhint),
                tocardinal2(t.indextolocformat),
                tocardinal2(t.glyphformat),
            }
        end

        tablewriters.hhea = function(fontfile)
            register(fontfile,"hhea")
            local t = fontfile.streams.horizontalheader
            local n = t and fontfile.nofglyphs or 0
            fontfile.hhea = concat {
                tocardinal4(t.version),
                tocardinal2(t.ascender),
                tocardinal2(t.descender),
                tocardinal2(t.linegap),
                tocardinal2(t.maxadvancewidth),
                tocardinal2(t.minleftsidebearing),
                tocardinal2(t.minrightsidebearing),
                tocardinal2(t.maxextent),
                tocardinal2(t.caretsloperise),
                tocardinal2(t.caretsloperun),
                tocardinal2(t.caretoffset),
                tocardinal2(t.reserved_1),
                tocardinal2(t.reserved_2),
                tocardinal2(t.reserved_3),
                tocardinal2(t.reserved_4),
                tocardinal2(t.metricdataformat),
                tocardinal2(n) -- t.nofmetrics
            }
        end

        tablewriters.vhea = function(fontfile)
            local t = fontfile.streams.verticalheader
            local n = t and fontfile.nofglyphs or 0
            register(fontfile,"vhea")
            fontfile.vhea = concat {
                tocardinal4(t.version),
                tocardinal2(t.ascender),
                tocardinal2(t.descender),
                tocardinal2(t.linegap),
                tocardinal2(t.maxadvanceheight),
                tocardinal2(t.mintopsidebearing),
                tocardinal2(t.minbottomsidebearing),
                tocardinal2(t.maxextent),
                tocardinal2(t.caretsloperise),
                tocardinal2(t.caretsloperun),
                tocardinal2(t.caretoffset),
                tocardinal2(t.reserved_1),
                tocardinal2(t.reserved_2),
                tocardinal2(t.reserved_3),
                tocardinal2(t.reserved_4),
                tocardinal2(t.metricdataformat),
                tocardinal2(n) -- t.nofmetrics
            }
        end

        tablewriters.maxp = function(fontfile)
            register(fontfile,"maxp")
            local t = fontfile.streams.maximumprofile
            local n = fontfile.nofglyphs
            -- if fontfile.streams.cffinfo then
                -- error
            -- end
            fontfile.maxp = concat {
                tocardinal4(0x00010000),
                tocardinal2(n),
                tocardinal2(t.points),
                tocardinal2(t.contours),
                tocardinal2(t.compositepoints),
                tocardinal2(t.compositecontours),
                tocardinal2(t.zones),
                tocardinal2(t.twilightpoints),
                tocardinal2(t.storage),
                tocardinal2(t.functiondefs),
                tocardinal2(t.instructiondefs),
                tocardinal2(t.stackelements),
                tocardinal2(t.sizeofinstructions),
                tocardinal2(t.componentelements),
                tocardinal2(t.componentdepth),
            }
        end

        tablecreators.loca = function(fontfile) return create(fontfile,"loca") end
        tablewriters .loca = function(fontfile) return write (fontfile,"loca") end

        tablecreators.glyf = function(fontfile) return create(fontfile,"glyf") end
        tablewriters .glyf = function(fontfile) return write (fontfile,"glyf") end

        tablecreators.hmtx = function(fontfile) return create(fontfile,"hmtx") end
        tablewriters .hmtx = function(fontfile) return write (fontfile,"hmtx") end

        tablecreators.vmtx = function(fontfile) return create(fontfile,"vmtx") end
        tablewriters .vmtx = function(fontfile) return write (fontfile,"vmtx") end

        tableloaders .cmap = function(fontfile) return read  (fontfile,"cmap") end
        tablewriters .cmap = function(fontfile) return write (fontfile,"cmap") end

        tableloaders .name = function(fontfile) return read  (fontfile,"name") end
        tablewriters .name = function(fontfile) return write (fontfile,"name") end

        tableloaders .post = function(fontfile) return read  (fontfile,"post") end
        tablewriters .post = function(fontfile) return write (fontfile,"post") end

    end

    mainwriters["truetype"] = function(details)
        --
        local fontfile         = openfontfile(details)
        local basefontname     = details.basefontname
        local streams          = details.streams
        local blobs            = streams.streams
        local fontheader       = streams.fontheader
        local horizontalheader = streams.horizontalheader
        local verticalheader   = streams.verticalheader
        local maximumprofile   = streams.maximumprofile
        local names            = streams.names
        local descriptions     = details.rawdata.descriptions
        local metadata         = details.rawdata.metadata
        local indices          = details.indices
        local metabbox         = { fontheader.xmin, fontheader.ymin, fontheader.xmax, fontheader.ymax }
        local indices,
              minindex,
              maxindex         = collectindices(descriptions,indices)
        local glyphstreams     = tablecreators.glyf(fontfile)
        local locations        = tablecreators.loca(fontfile)
        local horizontals      = tablecreators.hmtx(fontfile)
        local verticals        = tablecreators.vmtx(fontfile)
        --
        local zero2            = tocardinal2(0)
        local zero4            = tocardinal4(0)
        --
        local horizontal       = horizontalheader.nofmetrics > 0
        local vertical         = verticalheader.nofmetrics > 0
        --
        local streamoffset     = 0
        local lastoffset       = zero4
        local g, h, v          = 0, 0, 0
        --
        -- todo: locate notdef
        --
        if minindex > 0 then
            local blob = blobs[0]
            if blob and #blob > 0 then
                locations[0] = lastoffset
                g = g + 1 ; glyphstreams[g] = blob
                h = h + 1 ; horizontals [h] = zero4
                if vertical then
                    v = v + 1 ; verticals[v] = zero4
                end
                streamoffset = streamoffset + #blob
                lastoffset = tocardinal4(streamoffset)
            else
                print("missing .notdef")
            end
            -- todo: use a rep for h/v
            for index=1,minindex-1 do
                locations[index] = lastoffset
                h = h + 1 ; horizontals[h] = zero4
                if vertical then
                    v = v + 1 ; verticals[v] = zero4
                end
            end
        end
        for index=minindex,maxindex do
            locations[index] = lastoffset
            local data = indices[index]
            if data then
                local blob = blobs[index] -- we assume padding
                if blob and #blob > 0 then
                    g = g + 1 ; glyphstreams[g] = blob
                    h = h + 1 ; horizontals [h] = tocardinal2(data.width or 0)
                    h = h + 1 ; horizontals [h] = tocardinal2(data.boundingbox[1])
                    if vertical then
                        v = v + 1 ; verticals[v] = tocardinal2(data.height or 0)
                        v = v + 1 ; verticals[v] = tocardinal2(data.boundingbox[3])
                    end
                    streamoffset = streamoffset + #blob
                    lastoffset   = tocardinal4(streamoffset)
                else
                    h = h + 1 ; horizontals[h] = zero4
                    if vertical then
                        v = v + 1 ; verticals[v] = zero4
                    end
                    print("missing blob for index",index)
                end
            else
                h = h + 1 ; horizontals[h] = zero4
                if vertical then
                    v = v + 1 ; verticals[v] = zero4
                end
            end
        end
        locations[maxindex+1] = lastoffset -- cf spec
        --
        local nofglyphs             = maxindex + 1 -- include zero
        --
        fontheader.checksum         = 0
        fontheader.indextolocformat = 1
        maximumprofile.nofglyphs    = nofglyphs
        --
        fontfile.format             = "tff"
        fontfile.basefontname       = basefontname
        fontfile.nofglyphs          = nofglyphs
        --
        tablewriters.head(fontfile)
        tablewriters.hhea(fontfile)
        if vertical then
            tablewriters.vhea(fontfile)
        end
        tablewriters.maxp(fontfile)

        tablewriters.loca(fontfile)
        tablewriters.glyf(fontfile)

        tablewriters.hmtx(fontfile)
        if vertical then
            tablewriters.vmtx(fontfile)
        end
        --
        local fontdata = makefontfile(fontfile)
        local fontmeta = makemetadata(fontfile)
        --
        fontfile = closefontfile(fontfile)
        --
        local units       = metadata.units
        local basefont    = pdfconstant(basefontname)
        local widths      = widtharray(details,indices,maxindex,units)
        local object      = details.objectnumber
        local tounicode   = tounicodedictionary(details,indices,maxindex,basefontname)
        local tocidset    = tocidsetdictionary(indices,minindex,maxindex)
        local metabbox    = metadata.boundingbox or { 0, 0, 0, 0 }
        local fontbbox    = pdfarray { unpack(metabbox) }
        local ascender    = metadata.ascender
        local descender   = metadata.descender
        local capheight   = metadata.capheight or fontbbox[4]
        local stemv       = metadata.weightclass
        local italicangle = metadata.italicangle
        local xheight     = metadata.xheight or fontbbox[4]
        --
        if stemv then
            stemv = (stemv/65)^2 + 50
        end
        --
        local function scale(n)
            if n then
                return round((n) * 10000 / units) / 10
            else
                return 0
            end
        end
        --
        local reserved  = pdfreserveobject()
        local child = pdfdictionary {
            Type           = pdfconstant("Font"),
            Subtype        = pdfconstant("CIDFontType2"),
            BaseFont       = basefont,
            FontDescriptor = pdfreference(reserved),
            W              = pdfreference(pdfflushobject(widths)),
            CIDToGIDMap    = pdfconstant("Identity"),
            CIDSystemInfo  = pdfdictionary {
                Registry   = pdfstring("Adobe"),
                Ordering   = pdfstring("Identity"),
                Supplement = 0,
            }
        }
        local descendants = pdfarray {
            pdfreference(pdfflushobject(child)),
        }
        local descriptor = pdfdictionary {
            Type        = pdfconstant("FontDescriptor"),
            FontName    = basefont,
            Flags       = 4,
            FontBBox    = fontbbox,
            Ascent      = scale(ascender),
            Descent     = scale(descender),
            ItalicAngle = round(italicangle or 0),
            CapHeight   = scale(capheight),
            StemV       = scale(stemv),
            XHeight     = scale(xheight),
            FontFile2   = pdfreference(pdfflushstreamobject(fontdata)),
            CIDSet      = tocidset,
            Metadata    = fontmeta and pdfreference(pdfflushstreamobject(fontmeta)) or nil,
        }
        local parent = pdfdictionary {
            Type            = pdfconstant("Font"),
            Subtype         = pdfconstant("Type0"),
            Encoding        = pdfconstant(details.properties.writingmode == "vertical" and "Identity-V" or "Identity-H"),
            BaseFont        = basefont,
            DescendantFonts = descendants,
            ToUnicode       = pdfreference(pdfflushstreamobject(tounicode)),
        }
        pdfflushobject(reserved,descriptor)
        pdfflushobject(object,parent)
        --
     -- if trace_detail then
     --     local name = "temp.ttf"
     --     report_fonts("saving %a",name)
     --     io.savedata(name,fontdata)
     --     inspect(fonts.handlers.otf.readers.loadfont(name))
     -- end
        --
    end

    do
        -- todo : cff2

        local details    = {
            details        = true,
            platformnames  = true,
            platformextras = true,
        }

        tablecreators.cff = function(fontfile)
            fontfile.charstrings  = { }
            fontfile.charmappings = { }
            fontfile.cffstrings   = { }
            fontfile.cffhash      = { }
            return fontfile.charstrings , fontfile.charmappings
        end

        local todictnumber, todictreal, todictinteger, todictoffset  do

            local maxnum  =   0x7FFFFFFF
            local minnum  = - 0x7FFFFFFF - 1
            local epsilon = 1.0e-5

            local int2tag = "\28"
            local int4tag = "\29"
            local realtag = "\30"

            todictinteger = function(n)
                if not n then
                    return char(band(139,0xFF))
                elseif n >= -107 and n <= 107 then
                    return char(band(n + 139,0xFF))
                elseif n >= 108 and n <= 1131 then
                    n = 0xF700 + n - 108
                    return char(band(rshift(n,8),0xFF),band(n,0xFF))
                elseif n >= -1131 and n <= -108 then
                    n = 0xFB00 - n - 108
                    return char(band(rshift(n,8),0xFF),band(n,0xFF))
                elseif n >= -32768 and n <= 32767 then
                 -- return int2tag .. tointeger2(n)
                    return char(28,extract(n,8,8),extract(n,0,8))
                else
                 -- return int4tag .. tointeger4(n)
                    return char(29,extract(n,24,8),extract(n,16,8),extract(n,8,8),extract(n,0,8))
                end
            end

         -- -- not called that often
         --
         -- local encoder = readers.cffencoder
         --
         -- todictinteger = function(n)
         --     if not n then
         --         return encoder[0]
         --     elseif n >= -1131 and n <= 1131 then
         --         return encoder[n]
         --     elseif n >= -32768 and n <= 32767 then
         --      -- return int2tag .. tointeger2(n)
         --         return char(28,extract(n,8,8),extract(n,0,8))
         --     else
         --      -- return int4tag .. tointeger4(n)
         --         return char(29,extract(n,24,8),extract(n,16,8),extract(n,8,8),extract(n,0,8))
         --     end
         -- end

            todictoffset = function(n)
                return int4tag .. tointeger4(n)
            end

            local e  = false
            local z  = byte("0")
            local dp = 10
            local ep = 11
            local em = 12
            local mn = 14
            local es = 15

            local fg = formatters["%g"]

            todictreal = function(v)
                local s = fg(v)
                local t = { [0] = realtag }
                local n = 0
                for s in gmatch(s,".") do
                    if s == "e" or s == "E" then
                        e = true
                    elseif s == "+" then
                        -- skip
                    elseif s == "-" then
                        n = n + 1
                        if e then
                            t[n] = em
                            e = false
                        else
                            t[n] = mn
                        end
                    else
                        if e then
                            n = n + 1
                            t[n] = ep
                            e = false
                        end
                        n = n + 1
                        if s == "." then
                            t[n] = dp
                        else
                            t[n] = byte(s) - z
                        end
                    end
                end
                n = n + 1
                t[n] = es
                if (n % 2) ~= 0 then
                    n = n + 1
                    t[n] = es
                end
                local j = 0
                for i=1,n,2 do
                    j = j + 1
                    t[j] = char(t[i]*0x10+t[i+1])
                end
                t = concat(t,"",0,j)
                return t
            end

            todictnumber = function(n)
                if not n or n == 0 then
                    return todictinteger(0)
                elseif (n > maxnum or n < minnum or (abs(n - round(n)) > epsilon)) then
                    return todictreal(n)
                else
                    return todictinteger(n)
                end
            end

        end

        local todictkey = char

        local function todictstring(fontfile,value)
            if not value then
                value = ""
            end
            local s = fontfile.cffstrings
            local h = fontfile.cffhash
            local n = h[value]
            if not n then
                n = #s + 1
                s[n] = value
                h[value] = n
            end
            return todictinteger(390+n)
        end

        local function todictboolean(b)
            return todictinteger(b and 1 or 0)
        end

        local function todictdeltas(t)
            local r = { }
            for i=1,#t do
                r[i] = todictnumber(t[i]-(t[i-1] or 0))
            end
            return concat(r)
        end

        local function todictarray(t)
            local r = { }
            for i=1,#t do
                r[i] = todictnumber(t[i])
            end
            return concat(r)
        end

        local function writestring(target,source,offset,what)
            target[#target+1] = source
         -- report_fonts("string : %-11s %06i # %05i",what,offset,#source)
            return offset + #source
        end

        local function writetable(target,source,offset,what)
            source = concat(source)
            target[#target+1] = source
         -- report_fonts("table  : %-11s %06i # %05i",what,offset,#source)
            return offset + #source
        end

        local function writeindex(target,source,offset,what)
            local n = #source
            local t = #target
            t = t + 1 ; target[t] = tocardinal2(n)
            if n > 0 then
                local data = concat(source)
                local size = #data -- assume the worst
                local offsetsize, tocardinal
                if size < 0xFF then
                    offsetsize, tocardinal = 1, tocardinal1
                elseif size < 0xFFFF then
                    offsetsize, tocardinal = 2, tocardinal2
                elseif size < 0xFFFFFF then
                    offsetsize, tocardinal = 3, tocardinal3
                elseif size < 0xFFFFFFFF then
                    offsetsize, tocardinal = 4, tocardinal4
                end
             -- report_fonts("index  : %-11s %06i # %05i (%i entries with offset size %i)",what,offset,#data,n,offsetsize)
                offset = offset + 2 + 1 + (n + 1) * offsetsize + size
                -- bytes per offset
                t = t + 1 ; target[t] = tocardinal1(offsetsize)
                -- list of offsets (one larger for length calculation)
                local offset = 1 -- mandate
                t = t + 1 ; target[t] = tocardinal(offset)
                for i=1,n do
                    offset = offset + #source[i]
                    t = t + 1 ; target[t] = tocardinal(offset)
                end
                t = t + 1 ; target[t] = data
            else
             -- report_fonts("index  : %-11s %06i # %05i (no entries)",what,offset,0)
                offset = offset + 2
            end
         -- print("offset",offset,#concat(target))
            return offset
        end

        tablewriters.cff = function(fontfile)
            --
            local streams            = fontfile.streams
            local cffinfo            = streams.cffinfo or { }
            local names              = streams.names or { }
            local fontheader         = streams.fontheader or { }
            local basefontname       = fontfile.basefontname
            --
            local offset             = 0
            local dictof             = 0
            local target             = { }
            --
            local charstrings        = fontfile.charstrings
            local nofglyphs          = #charstrings + 1
            local fontmatrix         = { 0.001, 0, 0, 0.001, 0, 0 } -- todo
            local fontbbox           = fontfile.fontbbox
            local defaultwidth       = cffinfo.defaultwidth or 0
            local nominalwidth       = cffinfo.nominalwidth or 0
            local bluevalues         = cffinfo.bluevalues
            local otherblues         = cffinfo.otherblues
            local familyblues        = cffinfo.familyblues
            local familyotherblues   = cffinfo.familyotherblues
            local bluescale          = cffinfo.bluescale
            local blueshift          = cffinfo.blueshift
            local bluefuzz           = cffinfo.bluefuzz
            local stdhw              = cffinfo.stdhw
            local stdvw              = cffinfo.stdvw
            --
-- bluescale    = 0.039625
-- blueshift    = 7
-- bluefuzz     = 1
-- defaultwidth = 500
-- nominalwidth = 696
-- stdhw        = { 28, 36, 42, 48, 60 }
-- stdvw        = { 40, 60, 66, 72, 76, 80, 88, 94 }
            if defaultwidth == 0 then defaultwidth     = nil end
            if nomimalwidth == 0 then nominalwidth     = nil end
            if bluevalues        then bluevalues       = todictarray(bluevalues) end
            if otherblues        then otherblues       = todictarray(otherblues) end
            if familyblues       then familyblues      = todictarray(familyblues) end
            if familyotherblues  then familyotherblues = todictarray(familyotherblues) end
            if bluescale         then bluescale        = todictnumber(bluescale) end
            if blueshift         then blueshift        = todictnumber(blueshift) end
            if bluefuzz          then bluefuzz         = todictnumber(bluefuzz) end
--             if stdhw             then stdhw            = todictarray(stdhw) end
--             if stdvw             then stdvw            = todictarray(stdvw) end
if stdhw             then stdhw            = todictdeltas(stdhw) end
if stdvw             then stdvw            = todictdeltas(stdvw) end
            --
            local fontversion        = todictstring(fontfile,fontheader.fontversion or "uknown version")
            local familyname         = todictstring(fontfile,cffinfo.familyname or names.family or basefontname)
            local fullname           = todictstring(fontfile,cffinfo.fullname or basefontname)
            local weight             = todictstring(fontfile,cffinfo.weight or "Normal")
            local fontbbox           = todictarray(fontbbox)
            local strokewidth        = todictnumber(cffinfo.strokewidth)
            local monospaced         = todictboolean(cffinfo.monospaced)
            local italicangle        = todictnumber(cffinfo.italicangle)
            local underlineposition  = todictnumber(cffinfo.underlineposition)
            local underlinethickness = todictnumber(cffinfo.underlinethickness)
            local charstringtype     = todictnumber(2)
            local fontmatrix         = todictarray(fontmatrix)
            local ros                = todictstring(fontfile,"Adobe")    -- registry
                                    .. todictstring(fontfile,"Identity") -- identity
                                    .. todictnumber(0)                   -- supplement
            local cidcount           = todictnumber(fontfile.nofglyphs)
            local fontname           = todictstring(fontfile,basefontname)
            local fdarrayoffset      = todictoffset(0)
            local fdselectoffset     = todictoffset(0)
            local charstringoffset   = todictoffset(0)
            local charsetoffset      = todictoffset(0)
            local privateoffset      = todictoffset(0)
            --
            local defaultwidthx      = todictnumber(defaultwidth)
            local nominalwidthx      = todictnumber(nominalwidth)
            local private            = ""
                                    .. (defaultwidthx and (defaultwidthx .. todictkey(20)) or "")
                                    .. (nominalwidthx and (nominalwidthx .. todictkey(21)) or "")
                                    .. (bluevalues and (bluevalues .. todictkey(6)) or "")
                                    .. (otherblues and (otherblues .. todictkey(7)) or "")
                                    .. (familyblues and (familyblues .. todictkey(8)) or "")
                                    .. (familyotherblues and (familyotherblues .. todictkey(9)) or "")
                                    .. (bluescale and (bluescale .. todictkey(12,9)) or "")
                                    .. (blueshift and (blueshift .. todictkey(12,10)) or "")
                                    .. (bluefuzz and (bluefuzz .. todictkey(12,11)) or "")
                                    .. (stdhw and (stdhw .. todictkey(12,12)) or "")
                                    .. (stdvw and (stdvw .. todictkey(12,13)) or "")
            local privatesize        = todictnumber(#private)
            local privatespec        = privatesize .. privateoffset
            --
            -- header (fixed @ 1)
            --
            local header =
                tocardinal1(1) -- major
             .. tocardinal1(0) -- minor
             .. tocardinal1(4) -- header size
             .. tocardinal1(4) -- offset size
            --
            offset = writestring(target,header,offset,"header")
            --
            -- name index (fixed @ 2) (has to be sorted)
            --
            local names = {
                basefontname,
            }
            --
            offset = writeindex(target,names,offset,"names")
            --
            -- topdict index (fixed @ 3)
            --
            local topvars =
                charstringoffset .. todictkey(17)
             .. charsetoffset    .. todictkey(15)
             .. fdarrayoffset    .. todictkey(12,36)
             .. fdselectoffset   .. todictkey(12,37)
             .. privatespec      .. todictkey(18)
            --
            local topdict = {
                ros                   .. todictkey(12,30) -- first
             .. cidcount              .. todictkey(12,34)
             .. familyname            .. todictkey( 3)
             .. fullname              .. todictkey( 2)
             .. weight                .. todictkey( 4)
             .. fontbbox              .. todictkey( 5)
             .. monospaced            .. todictkey(12, 1)
             .. italicangle           .. todictkey(12, 2)
             .. underlineposition     .. todictkey(12, 3)
             .. underlinethickness    .. todictkey(12, 4)
             .. charstringtype        .. todictkey(12, 6)
             .. fontmatrix            .. todictkey(12, 7)
             .. strokewidth           .. todictkey(12, 8)
             .. topvars
            }
            --
            offset = writeindex(target,topdict,offset,"topdict")
            dictof = #target
            --
            -- string index (fixed @ 4)
            --
            offset = writeindex(target,fontfile.cffstrings,offset,"strings")
            --
            -- global subroutine index (fixed @ 5)
            --
            offset = writeindex(target,{},offset,"globals")
            --
            -- Encoding (cff1)
            --
            -- offset = writeindex(target,{},offset,"encoding")
            --
            -- Charsets
            --
            charsetoffset = todictoffset(offset)
            offset        = writetable(target,fontfile.charmappings,offset,"charsets")
            --
            -- fdselect
            --
            local fdselect =
                tocardinal1(3) -- format
             .. tocardinal2(1) -- n of ranges
             -- entry 1
             .. tocardinal2(0) -- first gid
             .. tocardinal1(0) -- fd index
             -- entry 2
--              .. tocardinal2(fontfile.sparsemax-1) -- sentinel
             .. tocardinal2(fontfile.sparsemax) -- sentinel
            --
            fdselectoffset = todictoffset(offset)
            offset         = writestring(target,fdselect,offset,"fdselect")
            --
            -- charstrings
            --
            charstringoffset = todictoffset(offset)
            offset           = writeindex(target,charstrings,offset,"charstrings")
            --
            -- font dict
            --
            -- offset = writeindex(target,{},offset,"fontdict")
            --
            -- private
            --
            privateoffset = todictoffset(offset)
            privatespec   = privatesize .. privateoffset
            offset        = writestring(target,private,offset,"private")
            --
            local fdarray = {
                fontname    .. todictkey(12,38)
             .. privatespec .. todictkey(18)
            }
            fdarrayoffset = todictoffset(offset)
            offset        = writeindex(target,fdarray,offset,"fdarray")
            --
            topdict = target[dictof]
            topdict = sub(topdict,1,#topdict-#topvars)
            topvars =
                charstringoffset .. todictkey(17)
             .. charsetoffset    .. todictkey(15)
             .. fdarrayoffset    .. todictkey(12,36)
             .. fdselectoffset   .. todictkey(12,37)
             .. privatespec      .. todictkey(18)
            target[dictof] = topdict .. topvars
            --
            target = concat(target)
         -- if trace_detail then
         --     local name = "temp.cff"
         --     report_fonts("saving %a",name)
         --     io.savedata(name,target)
         --     inspect(fonts.handlers.otf.readers.cffcheck(name))
         -- end
            return target
        end

    end

    -- todo: check widths (missing a decimal)

    mainwriters["opentype"] = function(details)
        --
        local fontfile       = openfontfile(details)
        local basefontname   = details.basefontname
        local streams        = details.streams
        local blobs          = streams.streams
        local fontheader     = streams.fontheader
        local maximumprofile = streams.maximumprofile
        local names          = streams.names
        local descriptions   = details.rawdata.descriptions
        local metadata       = details.rawdata.metadata
        local indices        = details.indices
        local metabbox       = { fontheader.xmin, fontheader.ymin, fontheader.xmax, fontheader.ymax }
        local indices,
              minindex,
              maxindex       = collectindices(descriptions,indices)
        local streamoffset   = 0
        local glyphstreams,
              charmappings   = tablecreators.cff(fontfile)
        --
        local zero2          = tocardinal2(0)
        local zero4          = tocardinal4(0)
        --
        -- we need to locate notdef (or store its unicode someplace)
        --
        local blob              = blobs[0] or "\14"
        local sparsemax         = 1
        local lastoffset        = zero4
        glyphstreams[sparsemax] = blob
        charmappings[sparsemax] = tocardinal1(0) -- format 0
        streamoffset            = streamoffset + #blob
        lastoffset              = tocardinal4(streamoffset)
        if minindex == 0 then
            minindex = 1
        end
        for index=minindex,maxindex do
            if indices[index] then
                local blob              = blobs[index] or "\14"
                sparsemax               = sparsemax + 1
                glyphstreams[sparsemax] = blob
                charmappings[sparsemax] = tocardinal2(index)
                streamoffset            = streamoffset + #blob
                lastoffset              = tocardinal4(streamoffset)
            end
        end
        --
        fontfile.nofglyphs    = maxindex + 1
        fontfile.sparsemax    = sparsemax
        fontfile.format       = "cff"
        fontfile.basefontname = basefontname
        fontfile.fontbbox     = metabbox
        --
        local fontdata = tablewriters.cff(fontfile)
        local fontmeta = makemetadata(fontfile)
        --
        fontfile = closefontfile(fontfile)
        --
        local units       = fontheader.units or metadata.units
        local basefont    = pdfconstant(basefontname)
        local widths      = widtharray(details,indices,maxindex,units)
        local object      = details.objectnumber
        local tounicode   = tounicodedictionary(details,indices,maxindex,basefontname)
        local tocidset    = tocidsetdictionary(indices,minindex,maxindex)
        local fontbbox    = pdfarray { unpack(metabbox) }
        local ascender    = metadata.ascender or 0
        local descender   = metadata.descender or 0
        local capheight   = metadata.capheight or fontbbox[4]
        local stemv       = metadata.weightclass
        local italicangle = metadata.italicangle
        local xheight     = metadata.xheight or fontbbox[4]
        if stemv then
            stemv = (stemv/65)^2 + 50
        else
-- stemv = 2
        end
        --
        local function scale(n)
            if n then
                return round((n) * 10000 / units) / 10
            else
                return 0
            end
        end
        --
        local reserved  = pdfreserveobject()
        local child = pdfdictionary {
            Type           = pdfconstant("Font"),
            Subtype        = pdfconstant("CIDFontType0"),
            BaseFont       = basefont,
            FontDescriptor = pdfreference(reserved),
            W              = pdfreference(pdfflushobject(widths)),
            CIDSystemInfo  = pdfdictionary {
                Registry   = pdfstring("Adobe"),
                Ordering   = pdfstring("Identity"),
                Supplement = 0,
            }
        }
        local descendants = pdfarray {
            pdfreference(pdfflushobject(child)),
        }
        local fontstream = pdfdictionary {
            Subtype = pdfconstant("CIDFontType0C"),
        }
        local descriptor = pdfdictionary {
            Type        = pdfconstant("FontDescriptor"),
            FontName    = basefont,
            Flags       = 4,
            FontBBox    = fontbbox,
            Ascent      = scale(ascender),
            Descent     = scale(descender),
            ItalicAngle = round(italicangle or 0),
            CapHeight   = scale(capheight),
            StemV       = scale(stemv),
            XHeight     = scale(xheight),
            CIDSet      = tocidset,
            FontFile3   = pdfreference(pdfflushstreamobject(fontdata,fontstream())),
            Metadata    = fontmeta and pdfreference(pdfflushstreamobject(fontmeta)) or nil,
        }
        local parent = pdfdictionary {
            Type            = pdfconstant("Font"),
            Subtype         = pdfconstant("Type0"),
            Encoding        = pdfconstant(details.properties.writingmode == "vertical" and "Identity-V" or "Identity-H"),
            BaseFont        = basefont,
            DescendantFonts = descendants,
            ToUnicode       = pdfreference(pdfflushstreamobject(tounicode)),
        }
        pdfflushobject(reserved,descriptor)
        pdfflushobject(object,parent)
    end

    mainwriters["type1"] = function(details)
        local s = details.streams
        local m = details.rawdata.metadata
        if m then
            local h = s.horizontalheader
            local c = s.cffinfo
            local n = s.names
            h.ascender  = m.ascender      or h.ascender
            h.descender = m.descender     or h.descender
            n.copyright = m.copyright     or n.copyright
            n.family    = m.familyname    or n.familyname
            n.fullname  = m.fullname      or n.fullname
            n.fontname  = m.fontname      or n.fontname
            n.subfamily = m.subfamilyname or n.subfamilyname
            n.version   = m.version       or n.version
            setmetatableindex(h,m)
            setmetatableindex(c,m)
            setmetatableindex(n,m)
        end
        mainwriters["opentype"](details)
    end

    -- todo: map pdf glyphs onto companion type 3 font .. can be set of small
    -- ones. maybe only private codes with proper tounicode

    local methods = { }

    function methods.pk(filename)
        local resolution  = 600
        local widthfactor = resolution / 72
        local scalefactor = 72 / resolution / 10
        local pkfullname  = resolvers.findpk(basedfontname,resolution)
        if not pkfullname or pkfullname == "" then
            return
        end
        local readers = fonts.handlers.tfm.readers
        local result  = readers.loadpk(pkfullname)
        if not result or result.error then
            return
        end
        return result.glyphs, widthfactor / 65536, scalefactor, readers.pktopdf
    end

    mainwriters["type3"] = function(details)
        local properties   = details.properties
        local basefontname = details.basefontname or properties.name
        local askedmethod  = "pk"
        local method       = methods[askedmethod]
        if not method then
            return
        end
        local glyphs, widthfactor, scalefactor, glyphtopdf = method(basedfontname)
        if not glyphs then
            return
        end
        local parameters  = details.parameters
        local object      = details.objectnumber
        local factor      = parameters.factor -- normally 1
        local f_name      = formatters["I%05i"]
        local fontmatrix  = pdfarray { scalefactor, 0, 0, scalefactor, 0, 0 }
        local indices,
              minindex,
              maxindex    = collectindices(details.fontdata.characters,details.indices)
        local widths      = pdfarray()
        local differences = pdfarray()
        local charprocs   = pdfdictionary()
        local basefont    = pdfconstant(basefontname)
        local llx, lly, urx, ury = 0, 0, 0, 0
        for i=1,maxindex-minindex+1 do
            widths[i] = 0
        end
        local d = 0
        local lastindex = -0xFFFF
        for index, data in sortedhash(indices) do
            local name  = f_name(index)
            local glyph = glyphs[index]
            if glyph then
                local width  = widthfactor * data.width
                local stream, lx, ly, ux, uy = glyphtopdf(glyph,width)
                if stream then
                    if index - 1 ~= lastindex then
                        d = d + 1 ; differences[d] = index
                    end
                    lastindex = index
                    d = d + 1 ; differences[d] = pdfconstant(name)
                    charprocs[name] = pdfreference(pdfflushstreamobject(stream))
                    widths[index-minindex+1] = width
                    if lx < llx then llx = lx end
                    if ux > urx then urx = ux end
                    if ly < lly then lly = ly end
                    if uy > ury then ury = uy end
                end
            end
        end
        local fontbbox = pdfarray { llx, lly, urx, ury }
        local encoding = pdfdictionary {
            Type        = pdfconstant("Encoding"),
            Differences = differences,
        }
        local tounicode  = tounicodedictionary(details,indices,maxindex,basefontname)
        local descriptor = pdfdictionary {
            Type        = pdfconstant("FontDescriptor"),
            FontName    = basefont,
            Flags       = 4,
            FontBBox    = fontbbox,
         -- Ascent      = scale(ascender),
         -- Descent     = scale(descender),
         -- ItalicAngle = round(italicangle or 0),
         -- CapHeight   = scale(capheight),
         -- StemV       = scale(stemv),
         -- XHeight     = scale(xheight),
         -- Metadata    = fontmeta and pdfreference(pdfflushstreamobject(fontmeta)) or nil,
        }
        local parent = pdfdictionary {
            Type            = pdfconstant("Font"),
            Subtype         = pdfconstant("Type3"),
            Name            = basefont,
            FontBBox        = fontbbox,
            FontMatrix      = fontmatrix,
            CharProcs       = pdfreference(pdfflushobject(charprocs)),
            Encoding        = pdfreference(pdfflushobject(encoding)),
            FirstChar       = minindex,
            LastChar        = maxindex,
            Widths          = pdfreference(pdfflushobject(widths)),
            FontDescriptor  = pdfreference(pdfflushobject(descriptor)),
            Resources       = lpdf.procset(true),
            ToUnicode       = pdfreference(pdfflushstreamobject(tounicode)),
        }
        pdfflushobject(reserved,descriptor)
        pdfflushobject(object,parent)
    end

end

-- writingmode

local usedfonts = fonts.hashes.identifiers -- for now
local noffonts  = 0

-- The main injector.

-- here we need to test for sharing otherwise we reserve too many
-- objects

local getstreamhash  = fonts.handlers.otf.getstreamhash
local loadstreamdata = fonts.handlers.otf.loadstreamdata

-- we can actually now number upwards (so not use fontid in /F)

local objects = setmetatableindex(function(t,k)
    local v
    if type(k) == "number" then
        local h = getstreamhash(k)
        v = rawget(t,h)
        if not v then
            v = pdfreserveobject()
            t[h] = v
        end
        if trace_fonts then
            report_fonts("font id %i bound to hash %s and object %i",k,h,v)
        end
    else
        report_fonts("fatal error, hash %s asked but not used",k,h,v)
        v = pdfreserveobject()
        t[k] = v
    end
    return v
end)

local n = 0

local names = setmetatableindex(function(t,k)
    local v
    if type(k) == "number" then
        local h = getstreamhash(k)
        v = rawget(t,h)
        if not v then
            n = n + 1
            v = n
            t[h] = v
        end
        if trace_fonts then
            report_fonts("font id %i bound to hash %s and name %i",k,h,n)
        end
    end
    t[k] = v
    return v
end)

function lpdf.flushfonts()

    local mainfonts = { }

    statistics.starttiming(objects)

    for fontid, used in sortedhash(lpdf.usedcharacters) do

     -- for a bitmap we need a different hash unless we stick to a fixed high
     -- resolution which makes much sense

        local hash = getstreamhash(fontid)
        if hash then
            local parent = mainfonts[hash]
            if not parent then
                local fontdata   = usedfonts[fontid]
                local rawdata    = fontdata.shared and fontdata.shared.rawdata
                local resources  = fontdata.resources
                local properties = fontdata.properties -- writingmode and type3
                local parameters = fontdata.parameters -- used in type3
                if not rawdata then
                    -- we have a virtual font that loaded directly ... at some point i will
                    -- sort this out (in readanddefine we need to do a bit more) .. the problem
                    -- is that we have a hybrid font then
                    for xfontid, xfontdata in next, fonts.hashes.identifiers do
                        if fontid ~= xfontid then
                            local xhash = getstreamhash(xfontid)
                            if hash == xhash then
                                rawdata  = xfontdata.shared and xfontdata.shared.rawdata
                                if rawdata then
                                    resources  = xfontdata.resources
                                    properties = xfontdata.properties
                                    parameters = xfontdata.parameters
                                    break
                                end
                            end
                        end
                    end
                end
                if rawdata then
                    parent = {
                        hash         = hash,
                        fontdata     = fontdata,
                        filename     = resources.filename or properties.filename or "unset",
                        indices      = { },
                        rawdata      = rawdata,
                        properties   = properties, -- we assume consistency
                        parameters   = parameters, -- we assume consistency
                        streams      = { },
                        objectnumber = objects[hash],
                        basefontname = subsetname(properties.psname or properties.name or "unset"),
                        name         = names[hash],
                    }
                    mainfonts[hash] = parent
                    noffonts = noffonts + 1
                end
            end
            if parent then
                local indices = parent.indices
                for k in next, used do
                    indices[k] = true
                end
            end
        end
    end

    for hash, details in sortedhash(mainfonts) do
        if next(details.indices) then
            local filename = details.filename
            if trace_fonts then
                report_fonts("embedding %a hashed as %a",filename,hash)
            end
            local properties = details.properties
            local bitmap     = properties.usedbitmap
            if bitmap then
                local format = "type3"
                local writer = mainwriters[format]
                if writer then
                    if trace_fonts then
                        report_fonts("using main writer %a",format)
                    end
                    writer(details)
                end
            else
                local format = properties.format
                local writer = mainwriters[format]
                if not writer then
                    -- at some point we should do this in the frontend but
                    -- luatex does it anyway then
                    local encoding, pfbfile, encfile = getmapentry(filename)
                    if encoding and pfbfile then
                        filename = pfbfile
                        format   = "type1"
                        --
                        -- another (temp) hack
                        local size   = details.fontdata.parameters.size
                        local factor = details.fontdata.parameters.factor
                        local descriptions = { }
                        local characters   = details.fontdata.characters
                        --
                        local names, _, _, metadata = fonts.constructors.handlers.pfb.loadvector(pfbfile)
                        local reverse  = table.swapped(names)
                        local vector   = encoding.vector
                        local indices  = details.indices
                        local remapped = { }
                        local factor   = number.dimenfactors.bp * size / 65536
                        for k, v in next, indices do
                            local name  = vector[k]
                            local index = reverse[name] or 0
                            local width = factor * (characters[k].width or 0)
                            descriptions[k] = {
                                width = width,
                                index = index,
                                name  = name,
                            }
                            remapped[index] = true
                        end
                        details.indices = remapped
                        --
                        details.rawdata.descriptions = descriptions
                        details.filename             = filename
                        details.rawdata.metadata     = { }
                        --
                        properties.filename = filename
                        properties.format   = format
                        writer = mainwriters[format]
                    end
                end
                if writer then
                    if trace_fonts then
                        report_fonts("using main writer %a",format)
                    end
                    -- better move this test to the writers .. cleaner
                    local streams = loadstreamdata(details.fontdata)
                    if streams and streams.fontheader and streams.names then
                        details.streams = streams
                        writer(details)
                        details.streams = { }
                    elseif trace_fonts then
                        -- can be ok for e.g. emoji
                        report_fonts("no streams in %a",filename)
                    end
                    -- free some  memory
                else -- if trace_fonts then
                    report_fonts("no %a writer for %a",format,filename)
                end
            end
        end
        mainfonts[details.hash] = false -- done
    end

    statistics.stoptiming(objects)

end

statistics.register("font embedding time",function()
    if noffonts > 0 then
        return format("%s seconds, %s fonts", statistics.elapsedtime(objects),noffonts)
    end
end)

updaters.register("backend.update.pdf",function()
    fonts.constructors.addtounicode = false
end)

-- this is temporary

local done = false

updaters.register("backend.update.pdf",function()
    if not done then
        function pdf.getfontobjnum          (k) return objects[k] end
        function pdf.getfontname            (k) return names  [k] end
        function pdf.includechar            ()  end -- maybe, when we need it
        function pdf.includefont            ()  end -- maybe, when we need it
        function pdf.includecharlist        ()  end -- maybe, when we need it
        function pdf.setomitcidset          (v) includecidset = not v end
        function pdf.setomitcharset         ()  end -- we don't need that in lmtx
        function pdf.setsuppressoptionalinfo()  end -- we don't need that in lmtx
        function pdf.mapfile                (n) loadmapfile(n) end
        function pdf.mapline                (n) loadmapline(n) end
        -- this will change
        lpdf.registerdocumentfinalizer(lpdf.flushfonts,1,"wrapping up fonts")
        done = true
    end
end)
