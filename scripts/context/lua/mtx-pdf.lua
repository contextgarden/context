if not modules then modules = { } end modules ['mtx-pdf'] = {
    version   = 1.001,
    comment   = "companion to mtxrun.lua",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local tonumber = tonumber
local format, gmatch, gsub = string.format, string.gmatch, string.gsub
local utfchar = utf.char
local concat = table.concat
local setmetatableindex, sortedhash, sortedkeys = table.setmetatableindex, table.sortedhash, table.sortedkeys

local helpinfo = [[
<?xml version="1.0"?>
<application>
 <metadata>
  <entry name="name">mtx-pdf</entry>
  <entry name="detail">ConTeXt PDF Helpers</entry>
  <entry name="version">0.10</entry>
 </metadata>
 <flags>
  <category name="basic">
   <subcategory>
    <flag name="info"><short>show some info about the given file</short></flag>
    <flag name="metadata"><short>show metadata xml blob</short></flag>
    <flag name="pretty"><short>replace newlines in metadata</short></flag>
    <flag name="fonts"><short>show used fonts (<ref name="detail)"/></short></flag>
   </subcategory>
   <subcategory>
    <example><command>mtxrun --script pdf --info foo.pdf</command></example>
    <example><command>mtxrun --script pdf --metadata foo.pdf</command></example>
    <example><command>mtxrun --script pdf --metadata --pretty foo.pdf</command></example>
   </subcategory>
  </category>
 </flags>
</application>
]]

local application = logs.application {
    name     = "mtx-pdf",
    banner   = "ConTeXt PDF Helpers 0.10",
    helpinfo = helpinfo,
}

local report = application.report

if pdfe then
    dofile(resolvers.findfile("lpdf-pde.lua","tex"))
else
    dofile(resolvers.findfile("lpdf-epd.lua","tex"))
end

scripts     = scripts     or { }
scripts.pdf = scripts.pdf or { }

local details = environment.argument("detail") or environment.argument("details")

local function loadpdffile(filename)
    if not filename or filename == "" then
        report("no filename given")
    elseif not lfs.isfile(filename) then
        report("unknown file '%s'",filename)
    else
        local pdffile  = lpdf.epdf.load(filename)
        if pdffile then
            return pdffile
        else
            report("no valid pdf file '%s'",filename)
        end
    end
end

function scripts.pdf.info(filename)
    local pdffile = loadpdffile(filename)
    if pdffile then
        local catalog      = pdffile.Catalog
        local info         = pdffile.Info
        local pages        = pdffile.pages
        local nofpages     = pdffile.nofpages

        local unset    = "<unset>"

        report("%-17s > %s","filename",          filename)
        report("%-17s > %s","pdf version",       catalog.Version      or unset)
        report("%-17s > %s","major version",     pdffile.majorversion or unset)
        report("%-17s > %s","minor version",     pdffile.minorversion or unset)
        report("%-17s > %s","number of pages",   nofpages             or 0)
        report("%-17s > %s","title",             info.Title           or unset)
        report("%-17s > %s","creator",           info.Creator         or unset)
        report("%-17s > %s","producer",          info.Producer        or unset)
        report("%-17s > %s","author",            info.Author          or unset)
        report("%-17s > %s","creation date",     info.CreationDate    or unset)
        report("%-17s > %s","modification date", info.ModDate         or unset)

        local function somebox(what)
            local box = string.lower(what)
            local width, height, start
            for i=1, nofpages do
                local page = pages[i]
                local bbox = page[what] or page.MediaBox or { 0, 0, 0, 0 }
                local w, h = bbox[4]-bbox[2],bbox[3]-bbox[1]
                if w ~= width or h ~= height then
                    if start then
                        report("%-17s > pages: %s-%s, width: %s, height: %s",box,start,i-1,width,height)
                    end
                    width, height, start = w, h, i
                end
            end
            report("%-17s > pages: %s-%s, width: %s, height: %s",box,start,nofpages,width,height)
        end

        if details then
            somebox("MediaBox")
            somebox("ArtBox")
            somebox("BleedBox")
            somebox("CropBox")
            somebox("TrimBox")
        else
            somebox("CropBox")
        end

     -- if details then
            local annotations = 0
            for i=1, nofpages do
                local page = pages[i]
                local a    = page.Annots
                if a then
                    annotations = annotations + #a
                end
            end
            if annotations > 0 then
                report("%-17s > %s", "annotations",annotations)
            end
     -- end

     -- if details then
            local d = pdffile.destinations
            local k = d and sortedkeys(d)
            if k and #k > 0 then
                report("%-17s > %s", "destinations",#k)
            end
            local d = pdffile.javascripts
            local k = d and sortedkeys(d)
            if k and #k > 0 then
                report("%-17s > %s", "javascripts",#k)
            end
            local d = pdffile.widgets
            if d and #d > 0 then
                report("%-17s > %s", "widgets",#d)
            end
            local d = pdffile.embeddedfiles
            local k = d and sortedkeys(d)
            if k and #k > 0 then
                report("%-17s > %s", "embeddedfiles",#k)
            end
    --  end

    end
end

function scripts.pdf.metadata(filename,pretty)
    local pdffile = loadpdffile(filename)
    if pdffile then
        local catalog  = pdffile.Catalog
        local metadata = catalog.Metadata
        if metadata then
            metadata = metadata()
            if pretty then
                metadata = gsub(metadata,"\r","\n")
            end
            report("metadata > \n\n%s\n",metadata)
        else
            report("no metadata")
        end
    end
end

local expanded = lpdf.epdf.expanded

local function getfonts(pdffile)
    local usedfonts = { }

    local function collect(where,tag)
        local resources = where.Resources
        if resources then
            local fontlist = resources.Font
            if fontlist then
                for k, v in expanded(fontlist) do
                    usedfonts[tag and (tag .. "." .. k) or k] = v
                end
            end
            local objects = resources.XObject
            if objects then
                for k, v in expanded(objects) do
                    collect(v,tag and (tag .. "." .. k) or k)
                end
            end
        end
    end

    for i=1,pdffile.nofpages do
        collect(pdffile.pages[i])
    end

    return usedfonts
end

local function getunicodes(font)
    local cid = font.ToUnicode
    if cid then
        cid = cid()
        local counts  = { }
        local indices = { }
     -- for s in gmatch(cid,"begincodespacerange%s*(.-)%s*endcodespacerange") do
     --     for a, b in gmatch(s,"<([^>]+)>%s+<([^>]+)>") do
     --         print(a,b)
     --     end
     -- end
        setmetatableindex(counts, function(t,k) t[k] = 0 return 0 end)
        for s in gmatch(cid,"beginbfrange%s*(.-)%s*endbfrange") do
            for first, last, offset in gmatch(s,"<([^>]+)>%s+<([^>]+)>%s+<([^>]+)>") do
                first  = tonumber(first,16)
                last   = tonumber(last,16)
                offset = tonumber(offset,16)
                offset = offset - first
                for i=first,last do
                    local c = i + offset
                    counts[c] = counts[c] + 1
                    indices[i] = true
                end
            end
        end
        for s in gmatch(cid,"beginbfchar%s*(.-)%s*endbfchar") do
            for old, new in gmatch(s,"<([^>]+)>%s+<([^>]+)>") do
                indices[tonumber(old,16)] = true
                for n in gmatch(new,"....") do
                    local c = tonumber(n,16)
                    counts[c] = counts[c] + 1
                end
            end
        end
        return counts, indices
    end
end

function scripts.pdf.fonts(filename)
    local pdffile = loadpdffile(filename)
    if pdffile then
        local usedfonts = getfonts(pdffile)
        local found     = { }
        local common    = table.setmetatableindex("table")
        for k, v in table.sortedhash(usedfonts) do
            local basefont = v.BaseFont
            local encoding = v.Encoding
            local subtype  = v.Subtype
            local unicode  = v.ToUnicode
            local counts,
                  indices  = getunicodes(v)
            local codes    = { }
            local chars    = { }
            local freqs    = { }
            local names    = { }
            if counts then
                codes = sortedkeys(counts)
                for i=1,#codes do
                    local k = codes[i]
                    if k > 32 then
                        local c = utfchar(k)
                        chars[i] = c
                        freqs[i] = format("U+%05X  %s  %s",k,counts[k] > 1 and "+" or " ", c)
                    else
                        freqs[i] = format("U+%05X  %s  --",k,counts[k] > 1 and "+" or " ")
                    end
                end
                if basefont and unicode then
                    local b = gsub(basefont,"^.*%+","")
                    local c = common[b]
                    for k in next, indices do
                        c[k] = true
                    end
                end
                for i=1,#codes do
                    codes[i] = format("U+%05X",codes[i])
                end
            end
            local d = encoding and encoding.Differences
            if d then
                for i=1,#d do
                    local di = d[i]
                    if type(di) == "string" then
                        names[#names+1] = di
                    end
                end
            end
            found[k] = {
                basefont = basefont or "no basefont",
                encoding = (d and "custom n=" .. #d) or "no encoding",
                subtype  = subtype or "no subtype",
                unicode  = tounicode and "unicode" or "no vector",
                chars    = chars,
                codes    = codes,
                freqs    = freqs,
                names    = names,
            }
        end

        if details then
            for k, v in sortedhash(found) do
                report("id         : %s",  k)
                report("basefont   : %s",  v.basefont)
                report("encoding   : % t", v.names)
                report("subtype    : %s",  v.subtype)
                report("unicode    : %s",  v.unicode)
                if #v.chars > 0 then
                    report("characters : % t", v.chars)
                end
                if #v.codes > 0 then
                    report("codepoints : % t", v.codes)
                end
                report("")
            end
            for k, v in sortedhash(common) do
                report("basefont   : %s",k)
                report("indices    : % t", sortedkeys(v))
                report("")
            end
        else
            local haschar = false
            for k, v in sortedhash(found) do
                if #v.chars > 0 then
                    haschar = true
                    break
                end
            end
            local results = { { "id", "basefont", "encoding", "subtype", "unicode", haschar and "characters" or nil } }
            for k, v in sortedhash(found) do
                results[#results+1] = { k, v.basefont, v.encoding, v.subtype, v.unicode, haschar and concat(v.chars," ") or nil }
            end
            utilities.formatters.formatcolumns(results)
            report(results[1])
            report("")
            for i=2,#results do
                report(results[i])
            end
            report("")
        end
    end
end

-- scripts.pdf.info("e:/tmp/oeps.pdf")
-- scripts.pdf.metadata("e:/tmp/oeps.pdf")
-- scripts.pdf.fonts("e:/tmp/oeps.pdf")
-- scripts.pdf.linearize("e:/tmp/oeps.pdf")

local filename = environment.files[1] or ""

if filename == "" then
    application.help()
elseif environment.argument("info") then
    scripts.pdf.info(filename)
elseif environment.argument("metadata") then
    scripts.pdf.metadata(filename,environment.argument("pretty"))
elseif environment.argument("fonts") then
    scripts.pdf.fonts(filename)
elseif environment.argument("exporthelp") then
    application.export(environment.argument("exporthelp"),filename)
else
    application.help()
end

-- a variant on an experiment by hartmut

--~ function downloadlinks(filename)
--~     local document = lpdf.epdf.load(filename)
--~     if document then
--~         local pages = document.pages
--~         for p = 1,#pages do
--~             local annotations = pages[p].Annots
--~             if annotations then
--~                 for a=1,#annotations do
--~                     local annotation = annotations[a]
--~                     local uri = annotation.Subtype == "Link" and annotation.A and annotation.A.URI
--~                     if uri and string.find(uri,"^http") then
--~                         os.execute("wget " .. uri)
--~                     end
--~                 end
--~             end
--~         end
--~     end
--~ end
