if not modules then modules = { } end modules ['lpdf-xmp'] = {
    version   = 1.001,
    comment   = "companion to lpdf-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
    comment   = "with help from Peter Rolf",
}

local tostring, type = tostring, type
local format, gsub = string.format, string.gsub
local utfchar = utf.char
local xmlfillin = xml.fillin
local md5HEX = md5.HEX

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

local pdfgetmetadata       = lpdf.getmetadata

-- The XMP packet wrapper is kind of fixed, see page 10 of XMPSpecificationsPart1.pdf from
-- XMP-Toolkit-SDK-CC201607.zip. So we hardcode the id.

local xpacket = format ( [[
<?xpacket begin="%s" id="W5M0MpCehiHzreSzNTczkc9d"?>

%%s

<?xpacket end="w"?>]], utfchar(0xFEFF) )

local mapping = {
    -- user defined keys (pdfx:)
    ["ConTeXt.Jobname"]      = { "context", "rdf:Description/pdfx:ConTeXt.Jobname" },
    ["ConTeXt.Time"]         = { "date",    "rdf:Description/pdfx:ConTeXt.Time" },
    ["ConTeXt.Url"]          = { "context", "rdf:Description/pdfx:ConTeXt.Url" },
    ["ConTeXt.Support"]      = { "context", "rdf:Description/pdfx:ConTeXt.Support" },
    ["ConTeXt.Version"]      = { "context", "rdf:Description/pdfx:ConTeXt.Version" },
    ["ConTeXt.LMTX"]         = { "context", "rdf:Description/pdfx:ConTeXt.LMTX" },
    ["TeX.Support"]          = { "metadata","rdf:Description/pdfx:TeX.Support" },
    ["LuaTeX.Version"]       = { "metadata","rdf:Description/pdfx:LuaTeX.Version" },
    ["LuaTeX.Functionality"] = { "metadata","rdf:Description/pdfx:LuaTeX.Functionality" },
    ["LuaTeX.LuaVersion"]    = { "metadata","rdf:Description/pdfx:LuaTeX.LuaVersion" },
    ["LuaTeX.Platform"]      = { "metadata","rdf:Description/pdfx:LuaTeX.Platform" },
    ["ID"]                   = { "id",      "rdf:Description/pdfx:ID" },                         -- has date
    -- Adobe PDF schema
    ["Keywords"]             = { "metadata","rdf:Description/pdf:Keywords" },
    ["Producer"]             = { "metadata","rdf:Description/pdf:Producer" },
 -- ["Trapped"]              = { "pdf",     "rdf:Description/pdf:Trapped" },                     -- '/False' in /Info, but 'False' in XMP
    -- Dublin Core schema
    ["Author"]               = { "metadata","rdf:Description/dc:creator/rdf:Seq/rdf:li" },
    ["Format"]               = { "metadata","rdf:Description/dc:format" },                       -- optional, but nice to have
    ["Subject"]              = { "metadata","rdf:Description/dc:description/rdf:Alt/rdf:li" },
    ["Title"]                = { "metadata","rdf:Description/dc:title/rdf:Alt/rdf:li" },
    -- XMP Basic schema
    ["CreateDate"]           = { "date",    "rdf:Description/xmp:CreateDate" },
    ["CreationDate"]         = { "date",    "rdf:Description/xmp:CreationDate" },                -- dummy
    ["Creator"]              = { "metadata","rdf:Description/xmp:CreatorTool" },
    ["MetadataDate"]         = { "date",    "rdf:Description/xmp:MetadataDate" },
    ["ModDate"]              = { "date",    "rdf:Description/xmp:ModDate" },                     -- dummy
    ["ModifyDate"]           = { "date",    "rdf:Description/xmp:ModifyDate" },
    -- XMP Media Management schema
    ["DocumentID"]           = { "id",      "rdf:Description/xmpMM:DocumentID" },                -- uuid
    ["InstanceID"]           = { "id",      "rdf:Description/xmpMM:InstanceID" },                -- uuid
    ["RenditionClass"]       = { "pdf",     "rdf:Description/xmpMM:RenditionClass" },            -- PDF/X-4
    ["VersionID"]            = { "pdf",     "rdf:Description/xmpMM:VersionID" },                 -- PDF/X-4
    -- additional entries
    -- PDF/X
    ["GTS_PDFXVersion"]      = { "pdf",     "rdf:Description/pdfxid:GTS_PDFXVersion" },
    -- optional entries
    -- all what is visible in the 'document properties --> additional metadata' window
    -- XMP Rights Management schema (optional)
    ["Marked"]               = { "pdf",      "rdf:Description/xmpRights:Marked" },
 -- ["Owner"]                = { "metadata", "rdf:Description/xmpRights:Owner/rdf:Bag/rdf:li" }, -- maybe useful (not visible)
 -- ["UsageTerms"]           = { "metadata", "rdf:Description/xmpRights:UsageTerms" },           -- maybe useful (not visible)
    ["WebStatement"]         = { "metadata", "rdf:Description/xmpRights:WebStatement" },
    -- Photoshop PDF schema (optional)
    ["AuthorsPosition"]      = { "metadata", "rdf:Description/photoshop:AuthorsPosition" },
    ["Copyright"]            = { "metadata", "rdf:Description/photoshop:Copyright" },
    ["CaptionWriter"]        = { "metadata", "rdf:Description/photoshop:CaptionWriter" },
}

lpdf.setsuppressoptionalinfo (
        0 --
    +   1 -- pdfnofullbanner
    +   2 -- pdfnofilename
    +   4 -- pdfnopagenumber
    +   8 -- pdfnoinfodict
    +  16 -- pdfnocreator
    +  32 -- pdfnocreationdate
    +  64 -- pdfnomoddate
    + 128 -- pdfnoproducer
    + 256 -- pdfnotrapped
 -- + 512 -- pdfnoid
)

local included = backends.included
local lpdfid   = lpdf.id

function lpdf.id() -- overload of ini
    return lpdfid(included.date)
end

local settrailerid = lpdf.settrailerid -- this is the wrapped one

local trailerid = nil
local dates     = nil

local function update()
    if trailer_id then
        local b = toboolean(trailer_id) or trailer_id == ""
        if b then
            trailer_id = "This file is processed by ConTeXt and LuaTeX."
        else
            trailer_id = tostring(trailer_id)
        end
        local h = md5HEX(trailer_id)
        if b then
            report_info("using frozen trailer id")
        else
            report_info("using hashed trailer id %a (%a)",trailer_id,h)
        end
        settrailerid(format("[<%s> <%s>]",h,h))
    end
    --
    local t = type(dates)
    if t == "number" or t == "string" then
        local d = converters.totime(dates)
        if d then
            included.date = true
            included.id   = "fake"
            report_info("forced date/time information %a will be used",lpdf.settime(d))
            settrailerid(false)
            return
        end
        if t == "string" then
            dates = toboolean(dates)
            included.date = dates
            if dates ~= false then
                included.id = true
            else
                report_info("no date/time but fake id information will be added")
                settrailerid(true)
                included.id = "fake"
            end
        end
    end
end

function lpdf.settrailerid(v) trailerid = v end
function lpdf.setdates    (v) dates     = v end

lpdf.registerdocumentfinalizer(update,"trailer id and dates",1)

directives.register("backend.trailerid", lpdf.settrailerid)
directives.register("backend.date",      lpdf.setdates)

local function permitdetail(what)
    local m = mapping[what]
    if m then
        return included[m[1]] and m[2]
    else
        return included[what] and true or false
    end
end

lpdf.permitdetail = permitdetail

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

interfaces.implement {
    name      = "setxmpfile",
    arguments = "string",
    actions   = setxmpfile
}

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
    local pattern = permitdetail(tag)
    if type(pattern) == "string" then
        xmlfillin(xmp or valid_xmp(),pattern,value,check)
    end
end

-- redefined

local pdfaddtoinfo  = lpdf.addtoinfo
local pdfaddxmpinfo = lpdf.addxmpinfo

function lpdf.addtoinfo(tag,pdfvalue,strvalue)
    local pattern = permitdetail(tag)
    if pattern then
        pdfaddtoinfo(tag,pdfvalue)
    end
    if type(pattern) == "string" then
        local value = strvalue or gsub(tostring(pdfvalue),"^%((.*)%)$","%1") -- hack
        if trace_info then
            report_info("set %a to %a",tag,value)
        end
        xmlfillin(xmp or valid_xmp(),pattern,value,check)
    end
end

local pdfaddtoinfo = lpdf.addtoinfo -- used later

-- for the do-it-yourselvers

function lpdf.insertxmpinfo(pattern,whatever,prepend)
    xml.insert(xmp or valid_xmp(),pattern,whatever,prepend)
end

function lpdf.injectxmpinfo(pattern,whatever,prepend)
    xml.inject(xmp or valid_xmp(),pattern,whatever,prepend)
end

-- flushing

local add_xmp_blob = true  directives.register("backend.xmp",function(v) add_xmp_blob = v end)

local function flushxmpinfo()
    commands.pushrandomseed()
    commands.setrandomseed(os.time())

    local documentid = "no unique document id here"
    local instanceid = "no unique instance id here"
    local metadata   = pdfgetmetadata()
    local time       = metadata.time
    local producer   = metadata.producer
    local creator    = metadata.creator

    if included.id ~= "fake" then
        documentid = "uuid:" .. os.uuid()
        instanceid = "uuid:" .. os.uuid()
    end

    pdfaddtoinfo("Producer",producer)
    pdfaddtoinfo("Creator",creator)
    pdfaddtoinfo("CreationDate",time)
    pdfaddtoinfo("ModDate",time)

    if add_xmp_blob then

        pdfaddxmpinfo("DocumentID",documentid)
        pdfaddxmpinfo("InstanceID",instanceid)
        pdfaddxmpinfo("Producer",producer)
        pdfaddxmpinfo("CreatorTool",creator)
        pdfaddxmpinfo("CreateDate",time)
        pdfaddxmpinfo("ModifyDate",time)
        pdfaddxmpinfo("MetadataDate",time)
        pdfaddxmpinfo("LuaTeX.Version",metadata.luatexversion)
        pdfaddxmpinfo("LuaTeX.Functionality",metadata.luatexfunctionality)
        pdfaddxmpinfo("LuaTeX.LuaVersion",metadata.luaversion)
        pdfaddxmpinfo("LuaTeX.Platform",metadata.platform)

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
        blob = format(xpacket,blob)
        if not verbose and lpdf.compresslevel() > 0 then
            blob = gsub(blob,">%s+<","><")
        end
        local r = pdfflushstreamobject(blob,md,false) -- uncompressed
        lpdf.addtocatalog("Metadata",pdfreference(r))
    end

    commands.poprandomseed() -- hack
end

--  this will be enabled when we can inhibit compression for a stream at the lua end

lpdf.registerdocumentfinalizer(flushxmpinfo,1,"metadata")

directives.register("backend.verbosexmp", function(v)
    verbose = v
end)
