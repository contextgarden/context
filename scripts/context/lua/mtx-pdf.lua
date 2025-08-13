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
local formatters = string.formatters
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
    <flag name="highlights"><short>show highlights</short></flag>
    <flag name="comments"><short>show comments</short></flag>
    <flag name="sign"><short>sign document (assumes signature template)</short></flag>
    <flag name="verify"><short>verify document</short></flag>
    <flag name="validate"><short>validate document (calls verapdf)</short></flag>
    <flag name="detail"><short>print detail to the console</short></flag>
    <flag name="userdata"><short>print userdata to the console</short></flag>
    <flag name="structure"><short>check the (context speficic) structure of the content</short></flag>
   </subcategory>
   <subcategory>
    <example><command>mtxrun --script pdf --info foo.pdf</command></example>
    <example><command>mtxrun --script pdf --metadata foo.pdf</command></example>
    <example><command>mtxrun --script pdf --metadata --pretty foo.pdf</command></example>
    <example><command>mtxrun --script pdf --stream=4 foo.pdf</command></example>
    <example><command>mtxrun --script pdf --sign --certificate=somesign.pem --password=test --uselibrary somefile</command></example>
    <example><command>mtxrun --script pdf --verify --certificate=somesign.pem --password=test --uselibrary somefile</command></example>
    <example><command>mtxrun --script pdf --detail=nofpages somefile</command></example>
    <example><command>mtxrun --script pdf --userdata=keylist [--format=lua|json|lines] somefile</command></example>
    <example><command>mtxrun --script pdf --validate --structure --details --save somefile</command></example>
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

local report   = application.report
local findfile = resolvers.findfile

if not pdfe then
    dofile(findfile("lpdf-epd.lua","tex"))
elseif CONTEXTLMTXMODE then
    local fullname
    dofile(findfile("util-dim.lua","tex"))
    dofile(findfile("lpdf-ini.lmt","tex"))
    dofile(findfile("lpdf-pde.lmt","tex"))
    dofile(findfile("lpdf-sig.lmt","tex"))
    fullname = findfile("lpdf-crp.lmt","tex") if fullname and fullname ~= "" then dofile(fullname) end
else
    dofile(findfile("lpdf-pde.lua","tex"))
end

scripts     = scripts     or { }
scripts.pdf = scripts.pdf or { }

local details = environment.argument("detail") or environment.argument("details")

local function loadpdffile(filename)
    if not filename or filename == "" then
        report("no filename given")
    end
    filename = file.addsuffix(filename,"pdf")
    if not lfs.isfile(filename) then
        report("unknown file %a",filename)
    else
        local ownerpassword = environment.arguments.ownerpassword
        local userpassword  = environment.arguments.userpassword
        if not ownerpassword then
            ownerpassword = userpassword
        end
        if not userpassword then
            userpassword = ownerpassword
        end
        local pdffile = lpdf.epdf.load(filename,userpassword,ownerpassword)
        if pdffile then
            return pdffile
        else
            report("no valid pdf file %a",filename)
        end
    end
end

-- Looks like we can get (even from programs using the adobe library):
--
-- 1 0 obj << /Metadata 3 0 R >> endobj
-- 3 0 obj << /Subtype /XML /Type /Metadata /Length 9104 >> stream ...
-- 2 0 obj << /Metadata 4 0 R /Subtype /XML /Type /Metadata >> endobj
-- 4 0 obj << /Length 9104 >> stream ...

do

    -- This is a goodie. Checking came up in the ctx chat (HHR) in relation
    -- to conversion and newer (lossless jpeg) file formats (not in pdf) but
    -- that could be dealt with later (at least get the size and resolution
    -- info).

    -- todo : svg
    -- todo : pdf (similar table)
    -- todo : jbig jbig2 jb2 (if needed)

    local graphics = nil

    function scripts.pdf.identify(filename)
        if graphics == nil then
            graphics = require("grph-img.lua") or false
        end
        if graphics then
            local info = graphics.identify(filename)
            if info and info.length then
                report("filename    : %s",filename)
                report("filetype    : %s",info.filetype)
                report("filesize    : %s",info.length)
                report("colordepth  : %s",info.colordepth)
                report("colorspace  : %s",graphics.colorspaces[info.colorspace])
                report("size        : %s %s",info.xsize,info.ysize)
                report("resolution  : %s %s",info.xres,info.yres)
                report("boundingbox : 0 0 %s %s (bp)",graphics.bpsize(info))
            end
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
        local metadata = catalog.Metadata

        local unset    = "<unset>"

        local title            = info.Title
        local creator          = info.Creator
        local producer         = info.Producer
        local author           = info.Author
        local creationdate     = info.CreationDate
        local modificationdate = info.ModDate

        if metadata then
            metadata = metadata()
            if metadata then
                local m = xml.convert(metadata)
                title            = title            or xml.text(m,"Description/title/**/*")
                author           = author           or xml.text(m,"Description/author/**/*")
                creator          = creator          or xml.text(m,"Description/CreatorTool")
                producer         = producer         or xml.text(m,"Description/Producer")
                creationdate     = creationdate     or xml.text(m,"Description/CreateDate")
                modificationdate = modificationdate or xml.text(m,"Description/ModifyDate")
            end
        end

        local function checked(str)
            return str and str ~= "" and str or unset
        end

        report("%-17s > %s","filename",          filename)
        report("%-17s > %s","pdf version",       catalog.Version      or unset)
        report("%-17s > %s","major version",     pdffile.majorversion or unset)
        report("%-17s > %s","minor version",     pdffile.minorversion or unset)
        report("%-17s > %s","number of pages",   nofpages             or 0)
        report("%-17s > %s","title",             checked(title))
        report("%-17s > %s","creator",           checked(creator))
        report("%-17s > %s","producer",          checked(producer))
        report("%-17s > %s","author",            checked(author))
        report("%-17s > %s","creation date",     checked(creationdate))
        report("%-17s > %s","modification date", checked(modificationdate))

        local function checked(what,str)
            if str ~= nil and str ~= "" then
                report("%-17s > %S",what,str)
            end
        end

        local viewerpreferences = catalog.ViewerPreferences
        local pagelayout        = catalog.PageLayout
        local pagemode          = catalog.PageMode
        local encrypted         = pdffile.encrypted
        local permissions       = pdffile.permissions

        checked("duplex",      viewerpreferences and viewerpreferences.Duplex)
        checked("page layout", pagelayout)
        checked("page mode",   pagemode)
        checked("encrypted",   encrypted and "yes" or nil)

        if permissions then
            report("%-17s > % t","permissions",table.sortedkeys(permissions))
        end

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

function scripts.pdf.validate(filename)
    local pdffile = file.addsuffix(filename,"pdf")
    if not lfs.isfile(pdffile) then
        report("invalid pdf file %a",pdffile)
        return
    end
    -- runner
    local data = os.resultof('verapdf "' .. pdffile .. '"')
    if data and #data > 0 then
        local x = xml.convert(data)
        if x then
            local r = xml.first(x,"buildInformation/releaseDetails[id='core'")
            if r then
                report("validator    : %s","verapdf")
                report("version      : %s",r.at.version or "unknown")
                report()
            else
                report("unsupported %a validator","verapdf")
                return
            end
            local r = xml.first(x,"validationReport")
            if r then
                local interaction  = environment.arguments.interaction
                local destinations = 0
                local annotations  = 0
                local at = r.at
                report("compliant    : %s",at.isCompliant  or "unknown")
                report("job status   : %s",at.jobEndStatus or "unknown")
                report("profile      : %s",at.profileName  or "unknown")
                report("statement    : %s",at.statement    or "unknown")
                r = xml.first(r,"/details")
                if r then
                    local at = r.at
                    report()
                    report("checks       : %i passed, %i failed",tonumber(at.passedChecks) or 0,tonumber(at.failedChecks) or 0)
                    report("rules        : %i passed, %i failed",tonumber(at.passedRules ) or 0,tonumber(at.failedRules ) or 0)
                 -- <rule> <!-- why is clause not an element but an attribute -->
                 --   <description>...</description>
                 --   <object>...</object>
                 --   <test>...</test>
                 --   <check>
                 --     <context>root/document[0]/StructTreeRoot[0](15 0 obj PDStructTreeRoot)</context>
                 --     <errorMessage>...</errorMessage>
                 --   </check>
                 -- </rule>
                    local reported   = { }
                    local duplicates = 0
                    local total      = 0
                    for e in xml.collected(r, "/rule/check[@status='failed']/..") do
                        local tc = xml.text(e,"/check/context")
                        local td = xml.text(e,"/description")
                        local te = xml.text(e,"/check/errorMessage")
                        if tc then
                            tc = gsub(tc,"%((%d+).-%)","(%1)")
                        end
                        if find(te,"annotation") then
                            annotations = annotations + 1
                        end
                        if find(te,"estination") then
                            destinations = destinations + 1
                        end
                        if interaction and not reported[te] then
                            report()
                            report("condition    : %s",td or "unknown")
                            report("error message: %s",te or "unknown")
                            report("object tree  : %s",tc or "unknown")
                            reported[te] = true
                            duplicates = duplicates + 1
                        end
                        total = total + 1
                    end
                    if total > 0 then
                        report()
                        report("duplicates   : %i",duplicates)
                        report("failed checks: %i",total)
                        if destinations or annotations then
                            report()
                            report("destinations : %i",destinations)
                            report("annotations  : %i",annotations)
                            if destinations + annotations >= total then
                                report()
                                report("the document looks okay, interaction is fragile in tagging and validation")
                            end
                            if not interaction then
                                report()
                                report("use --interaction to get more details")
                            end
                        end
                    end
                end
            end
        else
            report()
            report("no valid test result")
        end
    else
        report()
        report("make sure verapdf is installed")
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

function scripts.pdf.userdata(filename,name,format)
    local pdffile = loadpdffile(filename)
    if pdffile then
        local catalog  = pdffile.Catalog
        local userdata = catalog.LMTX_Userdata
        if userdata then
            if type(name) == "string" then
                local t = { }
                if type(format) == "string" then
                    for s in gmatch(name,"([^,]+)") do
                        t[s] = userdata[s]
                    end
                    if format == "lua" then
                        print(table.serialize(t,"userdata"))
                    elseif format == "json" then
                        print(utilities.json.tojson(t))
                    else
                        for k, v in sortedhash(t) do
                            print(k .. "=" .. v)
                        end
                    end
                else
                    for s in gmatch(name,"([^,]+)") do
                        t[#t+1] = userdata[s]
                    end
                    print(concat(t," "))
                end
            else
                for k, v in expanded(userdata) do
                    if k ~= "Type" then
                        report("%s : %s",k,v)
                    end
                end
            end
        else
            report("no userdata")
        end
    end
end

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
        local common    = setmetatableindex("table")
        for k, v in sortedhash(usedfonts) do
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
            local s = string.gsub(k,"(%d+)",function(s) return format("%05i",tonumber(s)) end)
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
                            local t = type(D)
                            if t == "table" then
                                local D1 = D[1]
                                local R1 = reverse[D1]
                                if not done then
                                    banner(pagenumber)
                                    done = true
                                end
                                if tonumber(R1) then
                                    report("intern, page %i",R1 or 0)
                                else
                                    report("intern, name %s",tostring(D1))
                                end
                            elseif t == "string" then
                                report("intern, name %s",D)
                            end
                        elseif S == "GoToR" then
                            local D = a.D
                            if D then
                                local F = a.F
                                if F then
                                    local D1 = D[1]
                                    if not done then
                                        banner(pagenumber)
                                        done = true
                                    end
                                    if tonumber(D1) then
                                        report("extern, page %i, file %s",D1 + 1,F)
                                    else
                                        report("extern, page %i, file %s, name %s",0,F,D[1])
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
                        report("tag %s, page %i",k,p)
                        insert(list[p],k)
                    end
                end
                for k, v in sortedhash(list) do
                    report("")
                    report("page %i, names : [ % | t ]",k,v)
                end
            end
        end
    end
end

function scripts.pdf.outlines(filename)

    local pdffile = loadpdffile(filename)
    if pdffile then

        local outlines     = pdffile.Catalog.Outlines
        local destinations = pdffile.destinations
        local pages        = pdffile.pages

        local function showdestination(current,depth,title)
            local action = current.A
            if type(title) == "table" then
                title = lpdf.frombytes(title[2],title[3])
            end
            if action then
                local subtype = action.S
                if subtype == "GoTo" then
                    local destination = action.D
                    local kind = type(destination)
                    if kind == "string" then
                        report("%wtitle %a, name %a",2*depth,title,destination)
                    elseif kind == "table" then
                        local pageref = #destination
                        if pageref then
                            local pagedata = pages[pageref]
                            if pagedata then
                                report("%wtitle %a, page %a",2*depth,title,pagedata.number)
                            end
                        end
                    end
                end
            else
                local destination = current.Dest
                if destination then
                    if type(destination) == "string" then
                        report("%wtitle %a, name %a",2*depth,title,destination)
                    else
                        local pagedata = destination and destination[1]
                        if pagedata and pagedata.Type == "Page" then
                            report("%wtitle %a, page %a",2*depth,title,pagedata.number)
                        end
                    end
                end
            end
            if title then
--                 report("%wtitle %a, unknown",2*depth,title)
            end
        end

        if outlines then

            local function traverse(current,depth)
                while current do
                    local title = current.Title -- can be pdfdoc or unicode
--                     local title = current("Title")  -- can be pdfdoc or unicode
                    if title then
                        showdestination(current,depth,title)
                    end
                    local first = current.First
                    if first then
                        local current = first
                        while current do
                            local title = current.Title
                            if title then
                                showdestination(current,depth,title)
                            end
                            traverse(current.First,depth+1)
                            current = current.Next
                        end
                    end
                    current = current.Next
                end
            end
            report("")
            report("outlines")
            report("")
            traverse(outlines,0)
            report("")

        else
            report("no outlines in %a",filename)
        end

    end

end

-- When I'm really bored, have a stack of new cd's or it's depressing whether I
-- might be willing to waste time on this. Actually I have to find back and use the
-- code MS and I used when checking out tagging but it might have gotton lost (note
-- for myself: check 2023 archive as there must be code somewhere that actually
-- printed the tree.).

function scripts.pdf.structure(filename)
    if lpdf.collectcontent then
        local pdffile = loadpdffile(filename)
        if pdffile then
            local arguments = environment.arguments
            local options   = {
                attachments = true,
                comments    = true,
                nobreaks    = false,
                details     = false,
                save        = arguments.save or false,
            }
            if arguments.attachments ~= nil then options.attachments = arguments.attachments end
            if arguments.comments    ~= nil then options.comments    = arguments.comments    end
            if arguments.nobreaks    ~= nil then options.nobreaks    = arguments.nobreaks    end
            if arguments.details     ~= nil then options.details     = arguments.details     end
            if arguments.detail      ~= nil then options.detail      = arguments.detail      end
            local result, statistics = lpdf.collectcontent(pdffile,options)
            if result and #result > 0 then
                local savename = options.save and file.nameonly(filename) .. "-tagview.xml"
                report()
                report("disclaimer:")
                report()
                report("This mostly is a simple check utility and we will complete this when we")
                report("feel the need or when a user has a test file and needs some checker. So,")
                report("feel free to ask on the mailing list. The output is yet sub-optimal and")
                report("complete (but it's not that hard to do).")
                report()
                report("This is not an official export, just a way to check how a text can be")
                report("seen and/or read. Users can define their own mappings and this is a way")
                report("to see what happens. Tags are sanitized to serve that purpose and some")
                report("extra information is provided by attributes.")
                if savename then
                    io.savedata(savename,result)
                else
                    report()
                    report()
                    print(result)
                    report()
                end
                report()
                report("options:")
                report()
                for k, v in sortedhash(options) do
                    report("%-12s : %S",k,v)
                end
                report()
                report("statistics:")
                report()
                for k, v in sortedhash(statistics) do
                    report("%-12s : %S",k,v)
                end
                if savename then
                    report()
                    report("result:",savename)
                    report()
                    report("%-12s : %S","filename",savename)
                    report("%-12s : %S bytes","filesize",#result)
                end
                if environment.argument("validate") then
                    report()
                    report("validation:")
                    report()
                    scripts.pdf.validate(filename)
                end
                report()
            else
                report("this file has no tags")
            end
        else
            report("this file is invalid")
        end
    else
        report("this feature is not supported")
    end
end

local function whatever(filename,asked,what,subtype)
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

        local function banner(pagenumber)
            report("")
            report("%s @ page %i",what,pagenumber)
            report("")
        end

        local function show(pagenumber)
            local page   = pages[pagenumber]
            local annots = page.Annots
            if annots then
                local done = false
                for i=1,#annots do
                    local annotation = annots[i]
                    local S = annotation.Subtype
                    if S == subtype then
                        local author   = annotation.T or "unknown"
                        local contents = annotation.Contents or "empty"
                        local rect     = annotation.Rect()
                        local name     = annotation.NM or "unset"
                        if not done then
                            banner(pagenumber)
                            done = true
                        end
                        local x = rect[1]
                        local y = rect[2]
                        local w = rect[3] - rect[1]
                        local h = rect[4] - rect[2]
                        report("position (%N,%N), dimensions (%N,%N), name %a, author %a, contents %a",
                            x,y,w,h,name,author,contents)
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

    end
end


function scripts.pdf.highlights(filename,asked)
    whatever(filename,asked,"highlights","Highlight")
end

function scripts.pdf.comments(filename,asked)
    whatever(filename,asked,"comments","Text")
end

local template = [[
\startTEXpage
\externalfigure[%s][page=%i]
\stopTEXpage
]]

function scripts.pdf.split(filename)
    local pdffile = loadpdffile(filename)
    if pdffile then
        local pages   = pdffile.nofpages
        local name    = file.nameonly(filename)
        local texname = "mtx-pdf-temp.tex"
        for page=1,pages do
            local pdfname = file.addsuffix(name.."-"..page,"pdf")
            local command = format("context --batch --nostats --silent --once %s --result=%s --purgeall",texname,pdfname)
            io.savedata(texname,format(template,filename,page))
            os.execute(command)
        end
        os.remove(texname)
    end
end

-- scripts.pdf.info("e:/tmp/oeps.pdf")
-- scripts.pdf.metadata("e:/tmp/oeps.pdf")
-- scripts.pdf.fonts("e:/tmp/oeps.pdf")
-- scripts.pdf.linearize("e:/tmp/oeps.pdf")

local filename = environment.files[1] or ""

if environment.argument("check") then
    -- an undocumented shortcut, mostly for ourselves
    environment.arguments.validate  = true
    environment.arguments.structure = true
    environment.arguments.details   = true
    environment.arguments.save      = true
end

if filename == "" then
    application.help()
elseif environment.argument("info") then
    scripts.pdf.info(filename)
elseif environment.argument("structure") then
    scripts.pdf.structure(filename)
elseif environment.argument("identify") then
    scripts.pdf.identify(filename)
elseif environment.argument("metadata") then
    scripts.pdf.metadata(filename,environment.argument("pretty"))
elseif environment.argument("formdata") then
    scripts.pdf.formdata(filename,environment.argument("save"))
elseif environment.argument("userdata") then
    scripts.pdf.userdata(filename,environment.argument("userdata"),environment.argument("format"))
elseif environment.argument("fonts") then
    scripts.pdf.fonts(filename)
elseif environment.argument("object") then
    scripts.pdf.object(filename,tonumber(environment.argument("object")))
elseif environment.argument("links") then
    scripts.pdf.links(filename,tonumber(environment.argument("page")))
elseif environment.argument("outlines") then
    scripts.pdf.outlines(filename)
elseif environment.argument("highlights") then
    scripts.pdf.highlights(filename,tonumber(environment.argument("page")))
------ structure before attachments and comments (are options there)
elseif environment.argument("verify") then
    scripts.pdf.verify(filename)
elseif environment.argument("comments") then
    scripts.pdf.comments(filename,tonumber(environment.argument("page")))
elseif environment.argument("signature") then
    scripts.pdf.signature(filename,environment.argument("save"))
elseif environment.argument("sign") then
    scripts.pdf.sign(filename)
elseif environment.argument("validate") then
    scripts.pdf.validate(filename)
elseif environment.argument("split") then
    scripts.pdf.split(filename)
elseif environment.argument("detail") then
    scripts.pdf.detail(filename,environment.argument("detail"))
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
