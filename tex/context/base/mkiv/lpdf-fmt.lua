if not modules then modules = { } end modules ['lpdf-fmt'] = {
    version   = 1.001,
    comment   = "companion to lpdf-ini.mkiv",
    author    = "Peter Rolf and Hans Hagen",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

-- Thanks to Luigi and Steffen for testing.

-- context --directives="backend.format=PDF/X-1a:2001" --trackers=backend.format yourfile

local tonumber = tonumber
local lower, gmatch, format, find = string.lower, string.gmatch, string.format, string.find
local concat, serialize, sortedhash = table.concat, table.serialize, table.sortedhash

local trace_format    = false  trackers.register("backend.format",    function(v) trace_format    = v end)
local trace_variables = false  trackers.register("backend.variables", function(v) trace_variables = v end)

local report_backend = logs.reporter("backend","profiles")

local backends, lpdf = backends, lpdf

local codeinjections           = backends.pdf.codeinjections

local variables                = interfaces.variables
local viewerlayers             = attributes.viewerlayers
local colors                   = attributes.colors
local transparencies           = attributes.transparencies

local pdfdictionary            = lpdf.dictionary
local pdfarray                 = lpdf.array
local pdfconstant              = lpdf.constant
local pdfreference             = lpdf.reference
local pdfflushobject           = lpdf.flushobject
local pdfstring                = lpdf.string
local pdfverbose               = lpdf.verbose
local pdfflushstreamfileobject = lpdf.flushstreamfileobject

local addtoinfo                = lpdf.addtoinfo
local injectxmpinfo            = lpdf.injectxmpinfo
local insertxmpinfo            = lpdf.insertxmpinfo

local settings_to_array        = utilities.parsers.settings_to_array
local settings_to_hash         = utilities.parsers.settings_to_hash

--[[
    Comments by Peter:

    output intent       : only one profile per color space (and device class)
    default color space : (theoretically) several profiles per color space possible

    The default color space profiles define the current gamuts (part of/all the
    colors we have in the document), while the output intent profile declares the
    gamut of the output devices (the colors that we get normally a printer or
    monitor).

    Example:

    I have two RGB pictures (both 'painted' in /DeviceRGB) and I declare sRGB as
    default color space for one picture and AdobeRGB for the other. As output
    intent I use ISO_coated_v2_eci.icc.

    If I had more than one output intent profile for the combination CMYK/printer I
    can't decide which one to use. But it is no problem to use several default color
    space profiles for the same color space as it's just a different color
    transformation. The relation between picture and profile is clear.
]]--

local channels = {
    gray = 1,
    grey = 1,
    rgb  = 3,
    cmyk = 4,
}

local prefixes = {
    gray = "DefaultGray",
    grey = "DefaultGray",
    rgb  = "DefaultRGB",
    cmyk = "DefaultCMYK",
}

local formatspecification = nil
local formatname          = nil

-- * correspondent document wide flags (write once) needed for permission tests

-- defaults as mt

local formats = utilities.storage.allocate {
    version = {
        external_icc_profiles   = 1.4, -- 'p' in name; URL reference of output intent
        jbig2_compression       = 1.4,
        jpeg2000_compression    = 1.5, -- not supported yet
        nchannel_colorspace     = 1.6, -- 'n' in name; n-channel colorspace support
        open_prepress_interface = 1.3, -- 'g' in name; reference to external graphics
        optional_content        = 1.5,
        transparency            = 1.4,
        object_compression      = 1.5,
        attachments             = 1.7,
    },
    default = {
        pdf_version             = 1.7,  -- todo: block tex primitive
        format_name             = "default",
        xmp_file                = "lpdf-pdx.xml",
        gray_scale              = true,
        cmyk_colors             = true,
        rgb_colors              = true,
        spot_colors             = true,
        calibrated_rgb_colors   = true, -- unknown
        cielab_colors           = true, -- unknown
        nchannel_colorspace     = true, -- unknown
        internal_icc_profiles   = true, -- controls profile inclusion
        external_icc_profiles   = true, -- controls profile inclusion
        include_intents         = true,
        open_prepress_interface = true, -- unknown
        optional_content        = true, -- todo: block at lua level
        transparency            = true, -- todo: block at lua level
        jbig2_compression       = true, -- todo: block at lua level (dropped anyway)
        jpeg2000_compression    = true, -- todo: block at lua level (dropped anyway)
        include_cidsets         = true,
        include_charsets        = true,
        attachments             = true,
        inject_metadata         = function()
            -- nothing
        end
    },
    data = {
        ["pdf/x-1a:2001"] = {
            pdf_version             = 1.3,
            format_name             = "PDF/X-1a:2001",
            xmp_file                = "lpdf-pdx.xml",
            gts_flag                = "GTS_PDFX",
            gray_scale              = true,
            cmyk_colors             = true,
            spot_colors             = true,
            internal_icc_profiles   = true,
            include_cidsets         = true,
            include_charsets        = true,
            attachments             = false,
            inject_metadata         = function()
                addtoinfo("GTS_PDFXVersion","PDF/X-1a:2001")
                injectxmpinfo("xml://rdf:RDF","<rdf:Description rdf:about='' xmlns:pdfxid='http://www.npes.org/pdfx/ns/id/'><pdfxid:GTS_PDFXVersion>PDF/X-1a:2001</pdfxid:GTS_PDFXVersion></rdf:Description>",false)
            end
        },
        ["pdf/x-1a:2003"] = {
            pdf_version             = 1.4,
            format_name             = "PDF/X-1a:2003",
            xmp_file                = "lpdf-pdx.xml",
            gts_flag                = "GTS_PDFX",
            gray_scale              = true,
            cmyk_colors             = true,
            spot_colors             = true,
            internal_icc_profiles   = true,
            include_cidsets         = true,
            include_charsets        = true,
            attachments             = false,
            inject_metadata         = function()
                addtoinfo("GTS_PDFXVersion","PDF/X-1a:2003")
                injectxmpinfo("xml://rdf:RDF","<rdf:Description rdf:about='' xmlns:pdfxid='http://www.npes.org/pdfx/ns/id/'><pdfxid:GTS_PDFXVersion>PDF/X-1a:2003</pdfxid:GTS_PDFXVersion></rdf:Description>",false)
            end
        },
        ["pdf/x-3:2002"] = {
            pdf_version             = 1.3,
            format_name             = "PDF/X-3:2002",
            xmp_file                = "lpdf-pdx.xml",
            gts_flag                = "GTS_PDFX",
            gray_scale              = true,
            cmyk_colors             = true,
            rgb_colors              = true,
            calibrated_rgb_colors   = true,
            spot_colors             = true,
            cielab_colors           = true,
            internal_icc_profiles   = true,
            include_intents         = true,
            include_cidsets         = true,
            include_charsets        = true,
            attachments             = false,
            inject_metadata         = function()
                addtoinfo("GTS_PDFXVersion","PDF/X-3:2002")
            end
        },
        ["pdf/x-3:2003"] = {
            pdf_version             = 1.4,
            format_name             = "PDF/X-3:2003",
            xmp_file                = "lpdf-pdx.xml",
            gts_flag                = "GTS_PDFX",
            gray_scale              = true,
            cmyk_colors             = true,
            rgb_colors              = true,
            calibrated_rgb_colors   = true,
            spot_colors             = true,
            cielab_colors           = true,
            internal_icc_profiles   = true,
            include_intents         = true,
            jbig2_compression       = true,
            include_cidsets         = true,
            include_charsets        = true,
            attachments             = false,
            inject_metadata         = function()
                addtoinfo("GTS_PDFXVersion","PDF/X-3:2003")
            end
        },
        ["pdf/x-4"] = {
            pdf_version             = 1.6,
            format_name             = "PDF/X-4",
            xmp_file                = "lpdf-pdx.xml",
            gts_flag                = "GTS_PDFX",
            gray_scale              = true,
            cmyk_colors             = true,
            rgb_colors              = true,
            calibrated_rgb_colors   = true,
            spot_colors             = true,
            cielab_colors           = true,
            internal_icc_profiles   = true,
            include_intents         = true,
            optional_content        = true,
            transparency            = true,
            jbig2_compression       = true,
            jpeg2000_compression    = true,
            object_compression      = true,
            include_cidsets         = true,
            include_charsets        = true,
            attachments             = false,
            inject_metadata         = function()
                injectxmpinfo("xml://rdf:RDF","<rdf:Description rdf:about='' xmlns:pdfxid='http://www.npes.org/pdfx/ns/id/'><pdfxid:GTS_PDFXVersion>PDF/X-4</pdfxid:GTS_PDFXVersion></rdf:Description>",false)
                insertxmpinfo("xml://rdf:Description/xmpMM:InstanceID","<xmpMM:VersionID>1</xmpMM:VersionID>",false)
                insertxmpinfo("xml://rdf:Description/xmpMM:InstanceID","<xmpMM:RenditionClass>default</xmpMM:RenditionClass>",false)
            end
        },
        ["pdf/x-4p"] = {
            pdf_version             = 1.6,
            format_name             = "PDF/X-4p",
            xmp_file                = "lpdf-pdx.xml",
            gts_flag                = "GTS_PDFX",
            gray_scale              = true,
            cmyk_colors             = true,
            rgb_colors              = true,
            calibrated_rgb_colors   = true,
            spot_colors             = true,
            cielab_colors           = true,
            internal_icc_profiles   = true,
            external_icc_profiles   = true,
            include_intents         = true,
            optional_content        = true,
            transparency            = true,
            jbig2_compression       = true,
            jpeg2000_compression    = true,
            object_compression      = true,
            include_cidsets         = true,
            include_charsets        = true,
            attachments             = false,
            inject_metadata         = function()
                injectxmpinfo("xml://rdf:RDF","<rdf:Description rdf:about='' xmlns:pdfxid='http://www.npes.org/pdfx/ns/id/'><pdfxid:GTS_PDFXVersion>PDF/X-4p</pdfxid:GTS_PDFXVersion></rdf:Description>",false)
                insertxmpinfo("xml://rdf:Description/xmpMM:InstanceID","<xmpMM:VersionID>1</xmpMM:VersionID>",false)
                insertxmpinfo("xml://rdf:Description/xmpMM:InstanceID","<xmpMM:RenditionClass>default</xmpMM:RenditionClass>",false)
            end
        },
        ["pdf/x-5g"] = {
            pdf_version             = 1.6,
            format_name             = "PDF/X-5g",
            xmp_file                = "lpdf-pdx.xml",
            gts_flag                = "GTS_PDFX",
            gray_scale              = true,
            cmyk_colors             = true,
            rgb_colors              = true,
            calibrated_rgb_colors   = true,
            spot_colors             = true,
            cielab_colors           = true,
            internal_icc_profiles   = true,
            include_intents         = true,
            open_prepress_interface = true,
            optional_content        = true,
            transparency            = true,
            jbig2_compression       = true,
            jpeg2000_compression    = true,
            object_compression      = true,
            include_cidsets         = true,
            include_charsets        = true,
            attachments             = false,
            inject_metadata         = function()
                -- todo
            end
        },
        ["pdf/x-5pg"] = {
            pdf_version             = 1.6,
            format_name             = "PDF/X-5pg",
            xmp_file                = "lpdf-pdx.xml",
            gts_flag                = "GTS_PDFX",
            gray_scale              = true,
            cmyk_colors             = true,
            rgb_colors              = true,
            calibrated_rgb_colors   = true,
            spot_colors             = true,
            cielab_colors           = true,
            internal_icc_profiles   = true,
            external_icc_profiles   = true,
            include_intents         = true,
            open_prepress_interface = true,
            optional_content        = true,
            transparency            = true,
            jbig2_compression       = true,
            jpeg2000_compression    = true,
            object_compression      = true,
            include_cidsets         = true,
            include_charsets        = true,
            attachments             = false,
            inject_metadata         = function()
                -- todo
            end
        },
        ["pdf/x-5n"] = {
            pdf_version             = 1.6,
            format_name             = "PDF/X-5n",
            xmp_file                = "lpdf-pdx.xml",
            gts_flag                = "GTS_PDFX",
            gray_scale              = true,
            cmyk_colors             = true,
            rgb_colors              = true,
            calibrated_rgb_colors   = true,
            spot_colors             = true,
            cielab_colors           = true,
            internal_icc_profiles   = true,
            include_intents         = true,
            optional_content        = true,
            transparency            = true,
            jbig2_compression       = true,
            jpeg2000_compression    = true,
            nchannel_colorspace     = true,
            object_compression      = true,
            include_cidsets         = true,
            include_charsets        = true,
            attachments             = false,
            inject_metadata         = function()
                -- todo
            end
        },
        ["pdf/a-1a:2005"] = {
            pdf_version             = 1.4,
            format_name             = "pdf/a-1a:2005",
            xmp_file                = "lpdf-pda.xml",
            gts_flag                = "GTS_PDFA1",
            gray_scale              = true,
            cmyk_colors             = true,
            rgb_colors              = true,
            spot_colors             = true,
            calibrated_rgb_colors   = true, -- unknown
            cielab_colors           = true, -- unknown
            include_intents         = true,
            forms                   = true, -- new: forms are allowed (with limitations); no JS,  other restrictions are unknown (TODO)
            tagging                 = true, -- new: the only difference to PDF/A-1b
            internal_icc_profiles   = true,
            include_cidsets         = true,
            include_charsets        = true,
            attachments             = false,
            inject_metadata         = function()
                injectxmpinfo("xml://rdf:RDF","<rdf:Description rdf:about='' xmlns:pdfaid='http://www.aiim.org/pdfa/ns/id/'><pdfaid:part>1</pdfaid:part><pdfaid:conformance>A</pdfaid:conformance></rdf:Description>",false)
            end
        },
        ["pdf/a-1b:2005"] = {
            pdf_version             = 1.4,
            format_name             = "pdf/a-1b:2005",
            xmp_file                = "lpdf-pda.xml",
            gts_flag                = "GTS_PDFA1",
            gray_scale              = true,
            cmyk_colors             = true,
            rgb_colors              = true,
            spot_colors             = true,
            calibrated_rgb_colors   = true, -- unknown
            cielab_colors           = true, -- unknown
            include_intents         = true,
            forms                   = true,
            internal_icc_profiles   = true,
            include_cidsets         = true,
            include_charsets        = true,
            attachments             = false,
            inject_metadata         = function()
                injectxmpinfo("xml://rdf:RDF","<rdf:Description rdf:about='' xmlns:pdfaid='http://www.aiim.org/pdfa/ns/id/'><pdfaid:part>1</pdfaid:part><pdfaid:conformance>B</pdfaid:conformance></rdf:Description>",false)
            end
        },
        -- Only PDF/A Attachments are allowed but we don't check the attachments
        -- for any quality: they are just blobs.
        ["pdf/a-2a"] = {
            pdf_version             = 1.7,
            format_name             = "pdf/a-2a",
            xmp_file                = "lpdf-pda.xml",
            gts_flag                = "GTS_PDFA1",
            gray_scale              = true,
            cmyk_colors             = true,
            rgb_colors              = true,
            spot_colors             = true,
            calibrated_rgb_colors   = true, -- unknown
            cielab_colors           = true, -- unknown
            include_intents         = true,
            forms                   = true,
            tagging                 = true,
            internal_icc_profiles   = true,
            transparency            = true, -- new
            jbig2_compression       = true,
            jpeg2000_compression    = true, -- new
            object_compression      = true, -- new
            include_cidsets         = false,
            include_charsets        = false,
            attachments             = true, -- new
            inject_metadata         = function()
                injectxmpinfo("xml://rdf:RDF","<rdf:Description rdf:about='' xmlns:pdfaid='http://www.aiim.org/pdfa/ns/id/'><pdfaid:part>2</pdfaid:part><pdfaid:conformance>A</pdfaid:conformance></rdf:Description>",false)
            end
        },
		["pdf/a-2b"] = {
            pdf_version             = 1.7,
            format_name             = "pdf/a-2b",
            xmp_file                = "lpdf-pda.xml",
            gts_flag                = "GTS_PDFA1",
            gray_scale              = true,
            cmyk_colors             = true,
            rgb_colors              = true,
            spot_colors             = true,
            calibrated_rgb_colors   = true, -- unknown
            cielab_colors           = true, -- unknown
            include_intents         = true,
            forms                   = true,
            tagging                 = false,
            internal_icc_profiles   = true,
            transparency            = true,
            jbig2_compression       = true,
            jpeg2000_compression    = true,
            object_compression      = true,
            include_cidsets         = false,
            include_charsets        = false,
            attachments             = true,
            inject_metadata         = function()
                injectxmpinfo("xml://rdf:RDF","<rdf:Description rdf:about='' xmlns:pdfaid='http://www.aiim.org/pdfa/ns/id/'><pdfaid:part>2</pdfaid:part><pdfaid:conformance>B</pdfaid:conformance></rdf:Description>",false)
            end
        },
        -- This is like the b variant, but it requires Unicode mapping of fonts
        -- which we do anyway.
		["pdf/a-2u"] = {
            pdf_version             = 1.7,
            format_name             = "pdf/a-2u",
            xmp_file                = "lpdf-pda.xml",
            gts_flag                = "GTS_PDFA1",
            gray_scale              = true,
            cmyk_colors             = true,
            rgb_colors              = true,
            spot_colors             = true,
            calibrated_rgb_colors   = true, -- unknown
            cielab_colors           = true, -- unknown
            include_intents         = true,
            forms                   = true,
            tagging                 = false,
            internal_icc_profiles   = true,
            transparency            = true,
            jbig2_compression       = true,
            jpeg2000_compression    = true,
            object_compression      = true,
            include_cidsets         = false,
            include_charsets        = false,
            attachments             = true,
            inject_metadata         = function()
                injectxmpinfo("xml://rdf:RDF","<rdf:Description rdf:about='' xmlns:pdfaid='http://www.aiim.org/pdfa/ns/id/'><pdfaid:part>2</pdfaid:part><pdfaid:conformance>U</pdfaid:conformance></rdf:Description>",false)
            end
        },
        -- Any type of attachment is allowed but we don't check the quality
        -- of them.
        ["pdf/a-3a"] = {
            pdf_version             = 1.7,
            format_name             = "pdf/a-3a",
            xmp_file                = "lpdf-pda.xml",
            gts_flag                = "GTS_PDFA1",
            gray_scale              = true,
            cmyk_colors             = true,
            rgb_colors              = true,
            spot_colors             = true,
            calibrated_rgb_colors   = true, -- unknown
            cielab_colors           = true, -- unknown
            include_intents         = true,
            forms                   = true,
            tagging                 = true,
            internal_icc_profiles   = true,
            transparency            = true,
            jbig2_compression       = true,
            jpeg2000_compression    = true,
            object_compression      = true,
            include_cidsets         = false,
            include_charsets        = false,
            attachments             = true,
            inject_metadata         = function()
                injectxmpinfo("xml://rdf:RDF","<rdf:Description rdf:about='' xmlns:pdfaid='http://www.aiim.org/pdfa/ns/id/'><pdfaid:part>3</pdfaid:part><pdfaid:conformance>A</pdfaid:conformance></rdf:Description>",false)
            end
        },
      ["pdf/a-3b"] = {
            pdf_version             = 1.7,
            format_name             = "pdf/a-3b",
            xmp_file                = "lpdf-pda.xml",
            gts_flag                = "GTS_PDFA1",
            gray_scale              = true,
            cmyk_colors             = true,
            rgb_colors              = true,
            spot_colors             = true,
            calibrated_rgb_colors   = true, -- unknown
            cielab_colors           = true, -- unknown
            include_intents         = true,
            forms                   = true,
            tagging                 = false,
            internal_icc_profiles   = true,
            transparency            = true,
            jbig2_compression       = true,
            jpeg2000_compression    = true,
            object_compression      = true,
            include_cidsets         = false,
            include_charsets        = false,
            attachments             = true,
            inject_metadata         = function()
                injectxmpinfo("xml://rdf:RDF","<rdf:Description rdf:about='' xmlns:pdfaid='http://www.aiim.org/pdfa/ns/id/'><pdfaid:part>3</pdfaid:part><pdfaid:conformance>B</pdfaid:conformance></rdf:Description>",false)
            end
        },
      ["pdf/a-3u"] = {
            pdf_version             = 1.7,
            format_name             = "pdf/a-3u",
            xmp_file                = "lpdf-pda.xml",
            gts_flag                = "GTS_PDFA1",
            gray_scale              = true,
            cmyk_colors             = true,
            rgb_colors              = true,
            spot_colors             = true,
            calibrated_rgb_colors   = true, -- unknown
            cielab_colors           = true, -- unknown
            include_intents         = true,
            forms                   = true,
            tagging                 = false,
            internal_icc_profiles   = true,
            transparency            = true,
            jbig2_compression       = true,
            jpeg2000_compression    = true,
            object_compression      = true,
            include_cidsets         = false,
            include_charsets        = false,
            attachments             = true,
            inject_metadata         = function()
                injectxmpinfo("xml://rdf:RDF","<rdf:Description rdf:about='' xmlns:pdfaid='http://www.aiim.org/pdfa/ns/id/'><pdfaid:part>3</pdfaid:part><pdfaid:conformance>U</pdfaid:conformance></rdf:Description>",false)
            end
        },
        ["pdf/ua-1"] = { -- based on PDF/A-3a, but no 'gts_flag'
            pdf_version             = 1.7,
            format_name             = "pdf/ua-1",
            xmp_file                = "lpdf-pua.xml",
            gray_scale              = true,
            cmyk_colors             = true,
            rgb_colors              = true,
            spot_colors             = true,
            calibrated_rgb_colors   = true, -- unknown
            cielab_colors           = true, -- unknown
            include_intents         = true,
            forms                   = true,
            tagging                 = true,
            internal_icc_profiles   = true,
            transparency            = true,
            jbig2_compression       = true,
            jpeg2000_compression    = true,
            object_compression      = true,
            include_cidsets         = true,
            include_charsets        = true, --- really ?
            attachments             = true,
            inject_metadata         = function()
                injectxmpinfo("xml://rdf:RDF","<rdf:Description rdf:about='' xmlns:pdfaid='http://www.aiim.org/pdfa/ns/id/'><pdfaid:part>3</pdfaid:part><pdfaid:conformance>A</pdfaid:conformance></rdf:Description>",false)
                injectxmpinfo("xml://rdf:RDF","<rdf:Description rdf:about='' xmlns:pdfuaid='http://www.aiim.org/pdfua/ns/id/'><pdfuaid:part>1</pdfuaid:part></rdf:Description>",false)
            end
        },
    }
}

lpdf.formats = formats -- it does not hurt to have this one visible

local filenames = {
    "colorprofiles.xml",
    "colorprofiles.lua",
}

local function locatefile(filename)
    local fullname = resolvers.findfile(filename,"icc",1,true)
    if not fullname or fullname == "" then
        fullname = resolvers.finders.byscheme("loc",filename) -- could be specific to the project
    end
    return fullname or ""
end

local function loadprofile(name,filename)
    local profile = false
    local databases = filename and filename ~= "" and settings_to_array(filename) or filenames
    for i=1,#databases do
        local filename = locatefile(databases[i])
        if filename and filename ~= "" then
            local suffix = file.suffix(filename)
            local lname = lower(name)
            if suffix == "xml" then
                local xmldata = xml.load(filename) -- no need for caching it
                if xmldata then
                    profile = xml.filter(xmldata,format('xml://profiles/profile/(info|filename)[lower(text())=="%s"]/../table()',lname))
                end
            elseif suffix == "lua" then
                local luadata = loadfile(filename)
                luadata = ludata and luadata()
                if luadata then
                    profile = luadata[name] or luadata[lname] -- hashed
                    if not profile then
                        for i=1,#luadata do
                            local li = luadata[i]
                            if lower(li.info) == lname then -- indexed
                                profile = li
                                break
                            end
                        end
                    end
                end
            end
            if profile then
                if next(profile) then
                    report_backend("profile specification %a loaded from %a",name,filename)
                    return profile
                elseif trace_format then
                    report_backend("profile specification %a loaded from %a but empty",name,filename)
                end
                return false
            end
        end
    end
    report_backend("profile specification %a not found in %a",name,concat(filenames, ", "))
end

local function urls(url)
    if not url or url == "" then
        return nil
    else
        local u = pdfarray()
        for url in gmatch(url,"([^, ]+)") do
            if find(url,"^http") then
                u[#u+1] = pdfdictionary {
                    FS = pdfconstant("URL"),
                    F  = pdfstring(url),
                }
            end
        end
        return u
    end
end

local function profilename(filename)
    return lower(file.basename(filename))
end

local internalprofiles = { }

local function handleinternalprofile(s,include)
    local filename, colorspace = s.filename or "", s.colorspace or ""
    if filename == "" or colorspace == "" then
        report_backend("error in internal profile specification: %s",serialize(s,false))
    else
        local tag = profilename(filename)
        local profile = internalprofiles[tag]
        if not profile then
            local colorspace = lower(colorspace)
            if include then
             -- local fullname = resolvers.findctxfile(filename) or ""
                local fullname = locatefile(filename)
                local channel = channels[colorspace] or nil
                if fullname == "" then
                    report_backend("error, couldn't locate profile %a",filename)
                elseif not channel then
                    report_backend("error, couldn't resolve channel entry for colorspace %a",colorspace)
                else
                    profile = pdfflushstreamfileobject(fullname,pdfdictionary{ N = channel },false) -- uncompressed
                    internalprofiles[tag] = profile
                    if trace_format then
                        report_backend("including %a color profile from %a",colorspace,fullname)
                    end
                end
            else
                internalprofiles[tag] = true
                if trace_format then
                    report_backend("not including %a color profile %a",colorspace,filename)
                end
            end
        end
        return profile
    end
end

local externalprofiles = { }

local function handleexternalprofile(s,include) -- specification (include ignored here)
    local name, url, filename, checksum, version, colorspace =
        s.info or s.filename or "", s.url or "", s.filename or "", s.checksum or "", s.version or "", s.colorspace or ""
    if false then -- somehow leads to invalid pdf
        local iccprofile = colors.iccprofile(filename)
        if iccprofile then
            name       = name       ~= "" and name       or iccprofile.tags.desc.cleaned       or ""
            url        = url        ~= "" and url        or iccprofile.tags.dmnd.cleaned       or ""
            checksum   = checksum   ~= "" and checksum   or file.checksum(iccprofile.fullname) or ""
            version    = version    ~= "" and version    or iccprofile.header.version          or ""
            colorspace = colorspace ~= "" and colorspace or iccprofile.header.colorspace       or ""
        end
     -- table.print(iccprofile)
    end
    if name == "" or url == "" or checksum == "" or version == "" or colorspace == "" or filename == "" then
        local profile = handleinternalprofile(s)
        if profile then
            report_backend("incomplete external profile specification, falling back to internal")
        else
            report_backend("error in external profile specification: %s",serialize(s,false))
        end
    else
        local tag = profilename(filename)
        local profile = externalprofiles[tag]
        if not profile then
            local d = pdfdictionary {
                ProfileName = name,                                     -- not file name!
                ProfileCS   = colorspace,
                URLs        = urls(url),                                -- array containing at least one URL
                CheckSum    = pdfverbose { "<", lower(checksum), ">" }, -- 16byte MD5 hash
                ICCVersion  = pdfverbose { "<", version, ">"  },        -- bytes 8..11 from the header of the ICC profile, as a hex string
            }
            profile = pdfflushobject(d)
            externalprofiles[tag] = profile
        end
        return profile
    end
end

local loadeddefaults = { }

local function handledefaultprofile(s,spec) -- specification
    local filename, colorspace = s.filename or "", lower(s.colorspace or "")
    if filename == "" or colorspace == "" then
        report_backend("error in default profile specification: %s",serialize(s,false))
    elseif not loadeddefaults[colorspace] then
        local tag = profilename(filename)
        local n = internalprofiles[tag] -- or externalprofiles[tag]
        if n == true then -- not internalized
            report_backend("no default profile %a for colorspace %a",filename,colorspace)
        elseif n then
            local a = pdfarray {
                pdfconstant("ICCBased"),
                pdfreference(n),
            }
             -- used in page /Resources, so this must be inserted at runtime
            lpdf.adddocumentcolorspace(prefixes[colorspace],pdfreference(pdfflushobject(a)))
            loadeddefaults[colorspace] = true
            report_backend("setting %a as default %a color space",filename,colorspace)
        else
            report_backend("no default profile %a for colorspace %a",filename,colorspace)
        end
    elseif trace_format then
        report_backend("a default %a colorspace is already in use",colorspace)
    end
end

local loadedintents = { }
local intents       = pdfarray()

local function handleoutputintent(s,spec)
    local url             = s.url or ""
    local filename        = s.filename or ""
    local name            = s.info or filename
    local id              = s.id or ""
    local outputcondition = s.outputcondition or ""
    local info            = s.info or ""
    if name == "" or id == "" then
        report_backend("error in output intent specification: %s",serialize(s,false))
    elseif not loadedintents[name] then
        local tag = profilename(filename)
        local internal, external = internalprofiles[tag], externalprofiles[tag]
        if internal or external then
            local d = {
                  Type                      = pdfconstant("OutputIntent"),
                  S                         = pdfconstant(spec.gts_flag or "GTS_PDFX"),
                  OutputConditionIdentifier = id,
                  RegistryName              = url,
                  OutputCondition           = outputcondition,
                  Info                      = info,
            }
            if internal and internal ~= true then
                d.DestOutputProfile    = pdfreference(internal)
            elseif external and external ~= true then
                d.DestOutputProfileRef = pdfreference(external)
            else
                report_backend("omitting reference to profile for intent %a",name)
            end
            intents[#intents+1] = pdfreference(pdfflushobject(pdfdictionary(d)))
            if trace_format then
                report_backend("setting output intent to %a with id %a for entry %a",name,id,#intents)
            end
        else
            report_backend("invalid output intent %a",name)
        end
        loadedintents[name] = true
    elseif trace_format then
        report_backend("an output intent with name %a is already in use",name)
    end
end

local function handleiccprofile(message,spec,name,filename,how,options,alwaysinclude,gts_flag)
    if name and name ~= "" then
        local list = settings_to_array(name)
        for i=1,#list do
            local name = list[i]
            local profile = loadprofile(name,filename)
            if trace_format then
                report_backend("handling %s %a",message,name)
            end
            if profile then
                if formatspecification.cmyk_colors then
                    profile.colorspace = profile.colorspace or "CMYK"
                else
                    profile.colorspace = profile.colorspace or "RGB"
                end
                local external = formatspecification.external_icc_profiles
                local internal = formatspecification.internal_icc_profiles
                local include  = formatspecification.include_intents
                local always, never = options[variables.always], options[variables.never]
                if always or alwaysinclude then
                    if trace_format then
                        report_backend("forcing internal profiles") -- can make preflight unhappy
                    end
                 -- internal, external = true, false
                    internal, external = not never, false
                elseif never then
                    if trace_format then
                        report_backend("forcing external profiles") -- can make preflight unhappy
                    end
                    internal, external = false, true
                end
                if external then
                    if trace_format then
                        report_backend("handling external profiles cf. %a",name)
                    end
                    handleexternalprofile(profile,false)
                else
                    if trace_format then
                        report_backend("handling internal profiles cf. %a",name)
                    end
                    if internal then
                        handleinternalprofile(profile,always or include)
                    else
                        report_backend("no profile inclusion for %a",formatname)
                    end
                end
                how(profile,spec)
            elseif trace_format then
                report_backend("unknown profile %a",name)
            end
        end
    end
end

local function flushoutputintents()
    if #intents > 0 then
        lpdf.addtocatalog("OutputIntents",pdfreference(pdfflushobject(intents)))
    end
end

lpdf.registerdocumentfinalizer(flushoutputintents,2,"output intents")

function codeinjections.setformat(s)
    local format   = s.format or ""
    local level    = tonumber(s.level)
    local intent   = s.intent or ""
    local profile  = s.profile or ""
    local option   = s.option or ""
    local filename = s.file or ""
    if format ~= "" then
        local spec = formats.data[lower(format)]
        if spec then
            formatspecification = spec
            formatname = spec.format_name
            report_backend("setting format to %a",formatname)
            local xmp_file = formatspecification.xmp_file or ""
            if xmp_file == "" then
                -- weird error
            else
                codeinjections.setxmpfile(xmp_file)
            end
            if not level then
                level = 3 -- good compromise, default anyway
            end
            local pdf_version         = spec.pdf_version * 10
            local inject_metadata     = spec.inject_metadata
            local majorversion        = math.div(pdf_version,10)
            local minorversion        = math.mod(pdf_version,10)
            local objectcompression   = spec.object_compression and pdf_version >= 15
            local compresslevel       = level or lpdf.compresslevel() -- keep default
            local objectcompresslevel = (objectcompression and (level or lpdf.objectcompresslevel())) or 0
            lpdf.setcompression(compresslevel,objectcompresslevel)
            lpdf.setversion(majorversion,minorversion)
            if objectcompression then
                report_backend("forcing pdf version %s.%s, compression level %s, object compression level %s",
                    majorversion,minorversion,compresslevel,objectcompresslevel)
            elseif compresslevel > 0 then
                report_backend("forcing pdf version %s.%s, compression level %s, object compression disabled",
                    majorversion,minorversion,compresslevel)
            else
                report_backend("forcing pdf version %s.%s, compression disabled",
                    majorversion,minorversion)
            end
            --
            -- cid sets can always omitted now, but those validators still complain so let's
            -- for a while keep it (for luigi):
            --
            lpdf.setomitcidset (formatspecification.include_cidsets  == false and 1 or 0) -- why a number
            lpdf.setomitcharset(formatspecification.include_charsets == false and 1 or 0) -- why a number
            --
            -- maybe block by pdf version
            --
            codeinjections.settaggingsupport(formatspecification.tagging)
            codeinjections.setattachmentsupport(formatspecification.attachments)
            --
            -- context.setupcolors { -- not this way
            --     cmyk = spec.cmyk_colors and variables.yes or variables.no,
            --     rgb  = spec.rgb_colors  and variables.yes or variables.no,
            -- }
            --
            colors.forcesupport(
                spec.gray_scale          or false,
                spec.rgb_colors          or false,
                spec.cmyk_colors         or false,
                spec.spot_colors         or false,
                spec.nchannel_colorspace or false
            )
            transparencies.forcesupport(
                spec.transparency        or false
            )
            viewerlayers.forcesupport(
                spec.optional_content    or false
            )
            viewerlayers.setfeatures(
                spec.has_order           or false -- new
            )
            --
            -- spec.jbig2_compression    : todo, block in image inclusion
            -- spec.jpeg2000_compression : todo, block in image inclusion
            --
            if type(inject_metadata) == "function" then
                inject_metadata()
            end
            local options = settings_to_hash(option)
            handleiccprofile("color profile",spec,profile,filename,handledefaultprofile,options,true)
            handleiccprofile("output intent",spec,intent,filename,handleoutputintent,options,false)
            if trace_variables then
                for k, v in sortedhash(formats.default) do
                    local v = formatspecification[k]
                    if type(v) ~= "function" then
                        report_backend("%a = %a",k,v or false)
                    end
                end
            end
            function codeinjections.setformat(noname)
                if trace_format then
                    report_backend("error, format is already set to %a, ignoring %a",formatname,noname.format)
                end
            end
        else
            report_backend("error, format %a is not supported",format)
        end
    elseif level then
        lpdf.setcompression(level,level)
    else
        -- we ignore this as we hook it in \everysetupbackend
    end
end

directives.register("backend.format", function(v) -- table !
    local tv = type(v)
    if tv == "table" then
        codeinjections.setformat(v)
    elseif tv == "string" then
        codeinjections.setformat { format = v }
    end
end)

interfaces.implement {
    name      = "setformat",
    actions   = codeinjections.setformat,
    arguments = { { "*" } }
}

function codeinjections.getformatoption(key)
    return formatspecification and formatspecification[key]
end

-- function codeinjections.getformatspecification()
--     return formatspecification
-- end

function codeinjections.supportedformats()
    local t = { }
    for k, v in sortedhash(formats.data) do
        t[#t+1] = k
    end
    return t
end

-- The following is somewhat cleaner but then we need to flag that there are
-- color spaces set so that the page flusher does not optimize the (at that
-- moment) still empty array away. So, next(d_colorspaces) should then become
-- a different test, i.e. also on flag. I'll add that when we need more forward
-- referencing.
--
-- local function embedprofile = handledefaultprofile
--
-- local function flushembeddedprofiles()
--     for colorspace, filename in next, defaults do
--         embedprofile(colorspace,filename)
--     end
-- end
--
-- local function handledefaultprofile(s)
--     defaults[lower(s.colorspace)] = s.filename
-- end
--
-- lpdf.registerdocumentfinalizer(flushembeddedprofiles,1,"embedded color profiles")
