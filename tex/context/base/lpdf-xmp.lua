if not modules then modules = { } end modules ['lpdf-xmp'] = {
    version   = 1.001,
    comment   = "companion to lpdf-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
    comment   = "with help from Peter Rolf",
}

local tostring = tostring
local format, random, char, gsub, concat = string.format, math.random, string.char, string.gsub, table.concat
local xmlfillin = xml.fillin

local trace_xmp  = false  trackers.register("backend.xmp",  function(v) trace_xmp  = v end)
local trace_info = false  trackers.register("backend.info", function(v) trace_info = v end)

local report_xmp  = logs.reporter("backend","xmp")
local report_info = logs.reporter("backend","info")

local backends, lpdf = backends, lpdf

local codeinjections       = backends.pdf.codeinjections -- normally it is registered

local pdfdictionary        = lpdf.dictionary
local pdfconstant          = lpdf.constant
local pdfreference         = lpdf.reference
local pdfflushstreamobject = lpdf.flushstreamobject

-- I wonder why this begin end is empty / w (no time now to look into it) / begin can also be "?"

local xpacket = [[
<?xpacket begin="﻿" id="%s"?>

%s

<?xpacket end="w"?>]]

local mapping = {
    -- user defined keys (pdfx:)
    ["ConTeXt.Jobname"] = "rdf:Description/pdfx:ConTeXt.Jobname",
    ["ConTeXt.Time"]    = "rdf:Description/pdfx:ConTeXt.Time",
    ["ConTeXt.Url"]     = "rdf:Description/pdfx:ConTeXt.Url",
    ["ConTeXt.Version"] = "rdf:Description/pdfx:ConTeXt.Version",
    ["ID"]              = "rdf:Description/pdfx:ID",
    ["PTEX.Fullbanner"] = "rdf:Description/pdfx:PTEX.Fullbanner",
    -- Adobe PDF schema
    ["Keywords"]        = "rdf:Description/pdf:Keywords",
    ["Producer"]        = "rdf:Description/pdf:Producer",
 -- ["Trapped"]         = "rdf:Description/pdf:Trapped", -- '/False' in /Info, but 'False' in XMP
    -- Dublin Core schema
    ["Author"]          = "rdf:Description/dc:creator/rdf:Seq/rdf:li",
    ["Format"]          = "rdf:Description/dc:format", -- optional, but nice to have
    ["Subject"]         = "rdf:Description/dc:description/rdf:Alt/rdf:li",
    ["Title"]           = "rdf:Description/dc:title/rdf:Alt/rdf:li",
    -- XMP Basic schema
    ["CreateDate"]      = "rdf:Description/xmp:CreateDate",
    ["Creator"]         = "rdf:Description/xmp:CreatorTool",
    ["MetadataDate"]    = "rdf:Description/xmp:MetadataDate",
    ["ModifyDate"]      = "rdf:Description/xmp:ModifyDate",
    -- XMP Media Management schema
    ["DocumentID"]      = "rdf:Description/xmpMM:DocumentID",
    ["InstanceID"]      = "rdf:Description/xmpMM:InstanceID",
    ["RenditionClass"]  = "rdf:Description/xmpMM:RenditionClass", -- PDF/X-4
    ["VersionID"]       = "rdf:Description/xmpMM:VersionID", -- PDF/X-4
    -- additional entries
    -- PDF/X
    ["GTS_PDFXVersion"] = "rdf:Description/pdfxid:GTS_PDFXVersion",
    -- optional entries
    -- all what is visible in the 'document properties --> additional metadata' window
    -- XMP Rights Management schema (optional)
    ["Marked"]          = "rdf:Description/xmpRights:Marked",
 -- ["Owner"]           = "rdf:Description/xmpRights:Owner/rdf:Bag/rdf:li", -- maybe useful (not visible)
 -- ["UsageTerms"]      = "rdf:Description/xmpRights:UsageTerms", -- maybe useful (not visible)
    ["WebStatement"]    = "rdf:Description/xmpRights:WebStatement",
    -- Photoshop PDF schema (optional)
    ["AuthorsPosition"] = "rdf:Description/photoshop:AuthorsPosition",
    ["Copyright"]       = "rdf:Description/photoshop:Copyright",
    ["CaptionWriter"]   = "rdf:Description/photoshop:CaptionWriter",
}

-- maybe some day we will load the xmp file at runtime

local xmp, xmpfile, xmpname = nil, nil, "lpdf-pdx.xml"

local function setxmpfile(name)
    if xmp then
        report_xmp("discarding loaded file %a",xmpfile)
        xmp = nil
    end
    xmpfile = name ~= "" and name
end

codeinjections.setxmpfile = setxmpfile
commands.setxmpfile       = setxmpfile

local function valid_xmp()
    if not xmp then
     -- local xmpfile = xmpfile or resolvers.findfile(xmpname) or ""
        if xmpfile and xmpfile ~= "" then
            xmpfile = resolvers.findfile(xmpfile) or ""
        end
        if not xmpfile or xmpfile == "" then
            xmpfile = resolvers.findfile(xmpname) or ""
        end
        if xmpfile ~= "" then
            report_xmp("using file %a",xmpfile)
        end
        local xmpdata = xmpfile ~= "" and io.loaddata(xmpfile) or ""
        xmp = xml.convert(xmpdata)
    end
    return xmp
end

function lpdf.addxmpinfo(tag,value,check)
    local pattern = mapping[tag]
    if pattern then
        xmlfillin(xmp or valid_xmp(),pattern,value,check)
    end
end

-- redefined

local pdfaddtoinfo  = lpdf.addtoinfo
local pdfaddxmpinfo = lpdf.addxmpinfo

function lpdf.addtoinfo(tag,pdfvalue,strvalue)
    pdfaddtoinfo(tag,pdfvalue)
    local value = strvalue or gsub(tostring(pdfvalue),"^%((.*)%)$","%1") -- hack
    if trace_info then
        report_info("set %a to %a",tag,value)
    end
    pdfaddxmpinfo(tag,value)
end

-- for the do-it-yourselvers

function lpdf.insertxmpinfo(pattern,whatever,prepend)
    xml.insert(xmp or valid_xmp(),pattern,whatever,prepend)
end

function lpdf.injectxmpinfo(pattern,whatever,prepend)
    xml.inject(xmp or valid_xmp(),pattern,whatever,prepend)
end

-- flushing

local t = { } for i=1,24 do t[i] = random() end

local function flushxmpinfo()
    commands.freezerandomseed(os.clock()) -- hack

    local t = { } for i=1,24 do t[i] = char(96 + random(26)) end
    local packetid = concat(t)

    local documentid = format("uuid:%s",os.uuid())
    local instanceid = format("uuid:%s",os.uuid())
    local producer   = format("LuaTeX-%0.2f.%s",tex.luatexversion/100,tex.luatexrevision)
    local creator    = "LuaTeX + ConTeXt MkIV"
    local time       = lpdf.timestamp()
    local fullbanner = status.banner

    pdfaddxmpinfo("DocumentID",      documentid)
    pdfaddxmpinfo("InstanceID",      instanceid)
    pdfaddxmpinfo("Producer",        producer)
    pdfaddxmpinfo("CreatorTool",     creator)
    pdfaddxmpinfo("CreateDate",      time)
    pdfaddxmpinfo("ModifyDate",      time)
    pdfaddxmpinfo("MetadataDate",    time)
    pdfaddxmpinfo("PTEX.Fullbanner", fullbanner)

    pdfaddtoinfo("Producer",         producer)
    pdfaddtoinfo("Creator",          creator)
    pdfaddtoinfo("CreationDate",     time)
    pdfaddtoinfo("ModDate",          time)
 -- pdfaddtoinfo("PTEX.Fullbanner",  fullbanner) -- no checking done on existence

    local blob = xml.tostring(xml.first(xmp or valid_xmp(),"/x:xmpmeta"))
    local md = pdfdictionary {
        Subtype = pdfconstant("XML"),
        Type    = pdfconstant("Metadata"),
    }
    if trace_xmp then
        report_xmp("data flushed, see log file")
        logs.pushtarget("logfile")
        report_xmp("start xmp blob")
        logs.newline()
        logs.writer(blob)
        logs.newline()
        report_xmp("stop xmp blob")
        logs.poptarget()
    end
    blob = format(xpacket,packetid,blob)
    if not verbose and tex.pdfcompresslevel > 0 then
        blob = gsub(blob,">%s+<","><")
    end
    local r = pdfflushstreamobject(blob,md,false) -- uncompressed
    lpdf.addtocatalog("Metadata",pdfreference(r))

    commands.defrostrandomseed() -- hack
end

--  his will be enabled when we can inhibit compression for a stream at the lua end

lpdf.registerdocumentfinalizer(flushxmpinfo,1,"metadata")

directives.register("backend.verbosexmp", function(v)
    verbose = v
end)
