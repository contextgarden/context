if not modules then modules = { } end modules ['mtx-pdf'] = {
    version   = 1.001,
    comment   = "companion to mtxrun.lua",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local tonumber = tonumber
local format, gmatch, gsub, match, find = string.format, string.gmatch, string.gsub, string.match, string.find
local utfchar = utf.char
local concat, insert, swapped = table.concat, table.insert, table.swapped
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
    <flag name="formdata"><short>show formdata</short></flag>
    <flag name="pretty"><short>replace newlines in metadata</short></flag>
    <flag name="fonts"><short>show used fonts (<ref name="detail"/>)</short></flag>
    <flag name="object"><short>show object</short></flag>
    <flag name="links"><short>show links</short></flag>
    <flag name="sign"><short>sign document (assumes signature template)</short></flag>
    <flag name="verify"><short>verify document</short></flag>
    <flag name="detail"><short>print detail to the console</short></flag>
   </subcategory>
   <subcategory>
    <example><command>mtxrun --script pdf --info foo.pdf</command></example>
    <example><command>mtxrun --script pdf --metadata foo.pdf</command></example>
    <example><command>mtxrun --script pdf --metadata --pretty foo.pdf</command></example>
    <example><command>mtxrun --script pdf --stream=4 foo.pdf</command></example>
    <example><command>mtxrun --script pdf --sign --certificate=somesign.pem --password=test --uselibrary somefile</command></example>
    <example><command>mtxrun --script pdf --verify --certificate=somesign.pem --password=test --uselibrary somefile</command></example>
    <example><command>mtxrun --script pdf --detail=nofpages somefile</command></example>
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

if not pdfe then
    dofile(resolvers.findfile("lpdf-epd.lua","tex"))
elseif CONTEXTLMTXMODE then
    dofile(resolvers.findfile("util-dim.lua","tex"))
    dofile(resolvers.findfile("lpdf-ini.lmt","tex"))
    dofile(resolvers.findfile("lpdf-pde.lmt","tex"))
    dofile(resolvers.findfile("lpdf-sig.lmt","tex"))
else
    dofile(resolvers.findfile("lpdf-pde.lua","tex"))
end
dofile(resolvers.findfile("util-jsn.lua","tex"))

scripts     = scripts     or { }
scripts.pdf = scripts.pdf or { }

local details = environment.argument("detail") or environment.argument("details")

local function loadpdffile(filename)
    if not filename or filename == "" then
        report("no filename given")
    elseif not lfs.isfile(filename) then
        report("unknown file %a",filename)
    else
        local pdffile = lpdf.epdf.load(filename)
        if pdffile then
            return pdffile
        else
            report("no valid pdf file %a",filename)
        end
    end
end

function scripts.pdf.info(filename)
    local pdffile = loadpdffile(filename)
    if pdffile then
        local catalog  = pdffile.Catalog
        local info     = pdffile.Info
        local pages    = pdffile.pages
        local nofpages = pdffile.nofpages

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
            for i=1,nofpages do
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

function scripts.pdf.detail(filename,detail)
    if detail == "pages" or detail == "nofpages" then
        local pdffile = loadpdffile(filename)
        print(pdffile and pdffile.nofpages or 0)
    end
end

local function flagstoset(flag,flags)
    local t = { }
    if flags then
        for k, v in next, flags do
            if (flag & v) ~= 0 then
                t[k] = true
            end
        end
    end
    return t
end

function scripts.pdf.formdata(filename,save)
    local pdffile = loadpdffile(filename)
    if pdffile then
        local widgets = pdffile.widgets
        if widgets then
            local results = { { "type", "name", "value" } }
            for i=1,#widgets do
                local annotation = widgets[i]
                local parent = annotation.Parent or { }
                local name   = annotation.T or parent.T
                local what   = annotation.FT or parent.FT
                if name and what then
                    local value = annotation.V and tostring(annotation.V) or ""
                    if value and value ~= "" then
                        local wflags = flagstoset(annotation.Ff or parent.Ff or 0, widgetflags)
                        if what == "Tx" then
                            if wflags.MultiLine then
                                wflags.MultiLine = nil
                                what = "text"
                            else
                                what = "line"
                            end
                            local default = annotation.V or ""
                        elseif what == "Btn" then
                            if wflags.Radio or wflags.RadiosInUnison then
                                what = "radio"
                            elseif wflags.PushButton then
                                what = "push"
                            else
                                what = "check"
                            end
                        elseif what == "Ch" then
                            -- F Ff FT Opt T | AA OC (rest follows)
                            if wflags.PopUp then
                                wflags.PopUp = nil
                                if wflags.Edit then
                                    what = "combo"
                                else
                                    what = "popup"
                                end
                            else
                                what = "choice"
                            end
                        elseif what == "Sig" then
                            what  = "signature"
                        else
                            what = nil
                        end
                        if what then
                            results[#results+1] = { what, name, value }
                        end
                    end
                end
            end
            if save then
                local values = { }
                for i=2,#results do
                    local result= results[i]
                    values[#values+1] = {
                        type  = result[1],
                        name  = result[2],
                        value = result[3],
                    }
                end
                local data = {
                    filename = filename,
                    values   = values,
                }
                local name = file.nameonly(filename) .. "-formdata"
                if save == "json" then
                    name = file.addsuffix(name,"json")
                    io.savedata(name,utilities.json.tojson(data))
                elseif save then
                    name = file.addsuffix(name,"lua")
                    table.save(name,data)
                end
                report("")
                report("%i widgets found, %i values saved in %a",#widgets,#results-1,name)
                report("")
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

function scripts.pdf.signature(filename,save)
    local pdffile = loadpdffile(filename)
    if pdffile then
        local widgets = pdffile.widgets
        if widgets then
            for i=1,#widgets do
                local annotation = widgets[i]
                local parent = annotation.Parent or { }
                local name   = annotation.T or parent.T
                local what   = annotation.FT or parent.FT
                if what == "Sig" then
                    local value = annotation.V
                    if value then
                        local contents = tostring(value.Contents) or ""
                        report("")
                        if save then
                            local name = file.nameonly(filename) .. "-signature.bin"
                            report("signature saved in %a",name)
                            io.savedata(name,string.tobytes(contents))
                        else
                            report("signature: %s",contents)
                        end
                        report("")
                        return
                    end
                end
            end
        end
        report("there is no signature")
    end
end

function scripts.pdf.sign(filename,save)
    local pdffile = file.addsuffix(filename,"pdf")
    if not lfs.isfile(pdffile) then
        report("invalid pdf file %a",pdffile)
        return
    end
    local certificate = environment.argument("certificate")
    local password    = environment.argument("password")
    if type(certificate) ~= "string" or type(password) ~= "string" then
        report("provide --certificate and --password")
        return
    end
    lpdf.sign {
        filename    = pdffile,
        certificate = certificate,
        password    = password,
        purge       = environment.argument("purge"),
        uselibrary  = environment.argument("uselibrary"),
    }
end

function scripts.pdf.verify(filename,save)
    local pdffile = file.addsuffix(filename,"pdf")
    if not lfs.isfile(pdffile) then
        report("invalid pdf file %a",pdffile)
        return
    end
    local certificate = environment.argument("certificate")
    local password    = environment.argument("password")
    if type(certificate) ~= "string" or type(password) ~= "string" then
        report("provide --certificate and --password")
        return
    end
    lpdf.verify {
        filename    = pdffile,
        certificate = certificate,
        password    = password,
        uselibrary  = environment.argument("uselibrary"),
    }
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
    local usedfonts  = { }

    local function collect(where,tag)
        local resources = where.Resources
        if resources then
            local fontlist = resources.Font
            if fontlist then
                for k, v in expanded(fontlist) do
                    usedfonts[tag and (tag .. "." .. k) or k] = v
                    if v.Subtype == "Type3" then
                        collect(v,tag and (tag .. "." .. k) or k)
                    end
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

-- todo: fromunicode16

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
                local first  = tonumber(first,16)
                local last   = tonumber(last,16)
                local offset = tonumber(offset,16)
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
         -- local freqs    = { }
            local names    = { }
            if counts then
                codes = sortedkeys(counts)
                for i=1,#codes do
                    local k = codes[i]
                    if k > 32 then
                        local c = utfchar(k)
                        chars[i] = c
                     -- freqs[i] = format("U+%05X  %s  %s",k,counts[k] > 1 and "+" or " ", c)
                    else
                        chars[i] = k == 32 and "SPACE" or format("U+%03X",k)
                     -- freqs[i] = format("U+%05X  %s  --",k,counts[k] > 1 and "+" or " ")
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
            if not basefont then
                local fontdescriptor = v.FontDescriptor
                if fontdescriptor then
                    basefont = fontdescriptor.FontName
                end
            end
            found[k] = {
                basefont = basefont or "no basefont",
                encoding = (d and "custom n=" .. #d) or "no encoding",
                subtype  = subtype or "no subtype",
                unicode  = unicode and "unicode" or "no vector",
                chars    = chars,
                codes    = codes,
             -- freqs    = freqs,
                names    = names,
            }
        end

        local haschar = false

        local list = { }
        for k, v in next, found do
            local s = string.gsub(k,"(%d+)",function(s) return string.format("%05i",tonumber(s)) end)
            list[s] = { k, v }
            if #v.chars > 0 then
                haschar = true
            end
        end

        if details then
            for k, v in sortedhash(found) do
--             for s, f in sortedhash(list) do
--                 local k = f[1]
--                 local v = f[2]
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
            local results = { { "id", "basefont", "encoding", "subtype", "unicode", haschar and "characters" or nil } }
            local shared  = { }
            for s, f in sortedhash(list) do
                local k = f[1]
                local v = f[2]
                local basefont   = v.basefont
                local characters = shared[basefont] or (haschar and concat(v.chars," ")) or nil
                results[#results+1] = { k, v.basefont, v.encoding, v.subtype, v.unicode, characters }
                if not shared[basefont] then
                    shared[basefont] = "shared with " .. k
                end
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

function scripts.pdf.object(filename,n)
    if n then
        local pdffile = loadpdffile(filename)
        if pdffile then
            print(lpdf.epdf.verboseobject(pdffile,n) or "no object with number " .. n)
        end
    end
end

function scripts.pdf.links(filename,asked)
    local pdffile = loadpdffile(filename)
    if pdffile then

        local pages    = pdffile.pages
        local nofpages = pdffile.nofpages

        if asked and (asked < 1 or asked > nofpages) then
            report("")
            report("no page %i, last page %i",asked,nofpages)
            report("")
            return
        end

        local reverse = swapped(pages)

        local function banner(pagenumber)
            report("")
            report("annotations @ page %i",pagenumber)
            report("")
        end

        local function show(pagenumber)
            local page   = pages[pagenumber]
            local annots = page.Annots
            if annots then
                local done = false
                for i=1,#annots do
                    local annotation = annots[i]
                    local a = annotation.A
                    if not a then
                        local d = annotation.Dest
                        if d then
                            a = { S = "GoTo", D = d } -- no need for a dict
                        end
                    end
                    if a then
                        local S = a.S
                        if S == "GoTo" then
                            local D = a.D
                            if D then
                                local D1 = D[1]
                                local R1 = reverse[D1]
                                if not done then
                                    banner(pagenumber)
                                    done = true
                                end
                                if tonumber(R1) then
                                    report("intern, page % 4i",R1 or 0)
                                else
                                    report("intern, name %s",tostring(D1))
                                end
                            end
                        elseif S == "GoToR" then
                            local D = a.D
                            if D then
                                local F = A.F
                                if F then
                                    local D1 = D[1]
                                    if not done then
                                        banner(pagenumber)
                                        done = true
                                    end
                                    if tonumber(D1) then
                                        report("extern, page % 4i, file %s",D1 + 1,F)
                                    else
                                        report("extern, page % 4i, file %s, name %s",0,F,D[1])
                                    end
                                end
                            end
                        elseif S == "URI" then
                            local URI = a.URI
                            if URI then
                                report("extern, uri   %a",URI)
                            end
                        end
                    end
                end
            end
        end

        if asked then
            show(asked)
        else
            for pagenumber=1,nofpages do
                show(pagenumber)
            end
        end

        local destinations = pdffile.destinations
        if destinations then
            if asked then
                report("")
                report("destinations to page %i",asked)
                report("")
                for k, v in sortedhash(destinations) do
                    local D = v.D
                    if D then
                        local p = reverse[D[1]] or 0
                        if p == asked then
                            report(k)
                        end
                    end
                end
            else
                report("")
                report("destinations")
                report("")
                local list = setmetatableindex("table")
                for k, v in sortedhash(destinations) do
                    local D = v.D
                    if D then
                        local p = reverse[D[1]]
                        report("tag %s, page % 4i",k,p)
                        insert(list[p],k)
                    end
                end
                for k, v in sortedhash(list) do
                    report("")
                    report("page %i, names % t",k,v)
                end
            end
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
elseif environment.argument("formdata") then
    scripts.pdf.formdata(filename,environment.argument("save"))
elseif environment.argument("fonts") then
    scripts.pdf.fonts(filename)
elseif environment.argument("object") then
    scripts.pdf.object(filename,tonumber(environment.argument("object")))
elseif environment.argument("links") then
    scripts.pdf.links(filename,tonumber(environment.argument("page")))
elseif environment.argument("signature") then
    scripts.pdf.signature(filename,environment.argument("save"))
elseif environment.argument("sign") then
    scripts.pdf.sign(filename)
elseif environment.argument("detail") then
    scripts.pdf.detail(filename,environment.argument("detail"))
elseif environment.argument("verify") then
    scripts.pdf.verify(filename)
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
