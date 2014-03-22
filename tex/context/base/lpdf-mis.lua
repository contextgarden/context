if not modules then modules = { } end modules ['lpdf-mis'] = {
    version   = 1.001,
    comment   = "companion to lpdf-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- Although we moved most pdf handling to the lua end, we didn't change
-- the overall approach. For instance we share all resources i.e. we
-- don't make subsets for each xform or page. The current approach is
-- quite efficient. A big difference between MkII and MkIV is that we
-- now use forward references. In this respect the MkII code shows that
-- it evolved over a long period, when backends didn't provide forward
-- referencing and references had to be tracked in multiple passes. Of
-- course there are a couple of more changes.

local next, tostring = next, tostring
local format, gsub, formatters = string.format, string.gsub, string.formatters
local texset = tex.set

local backends, lpdf, nodes = backends, lpdf, nodes

local nodeinjections       = backends.pdf.nodeinjections
local codeinjections       = backends.pdf.codeinjections
local registrations        = backends.pdf.registrations

local copy_node            = node.copy

local nodepool             = nodes.pool
local pdfliteral           = nodepool.pdfliteral
local register             = nodepool.register

local pdfdictionary        = lpdf.dictionary
local pdfarray             = lpdf.array
local pdfboolean           = lpdf.boolean
local pdfconstant          = lpdf.constant
local pdfreference         = lpdf.reference
local pdfunicode           = lpdf.unicode
local pdfverbose           = lpdf.verbose
local pdfstring            = lpdf.string
local pdfflushobject       = lpdf.flushobject
local pdfflushstreamobject = lpdf.flushstreamobject
local pdfaction            = lpdf.action

local formattedtimestamp   = lpdf.pdftimestamp
local adddocumentextgstate = lpdf.adddocumentextgstate
local addtocatalog         = lpdf.addtocatalog
local addtoinfo            = lpdf.addtoinfo
local addtopageattributes  = lpdf.addtopageattributes
local addtonames           = lpdf.addtonames

local variables            = interfaces.variables
local v_stop               = variables.stop

local positive             = register(pdfliteral("/GSpositive gs"))
local negative             = register(pdfliteral("/GSnegative gs"))
local overprint            = register(pdfliteral("/GSoverprint gs"))
local knockout             = register(pdfliteral("/GSknockout gs"))

local function initializenegative()
    local a = pdfarray { 0, 1 }
    local g = pdfconstant("ExtGState")
    local d = pdfdictionary {
        FunctionType = 4,
        Range        = a,
        Domain       = a,
    }
    local negative = pdfdictionary { Type = g, TR = pdfreference(pdfflushstreamobject("{ 1 exch sub }",d)) }
    local positive = pdfdictionary { Type = g, TR = pdfconstant("Identity") }
    adddocumentextgstate("GSnegative", pdfreference(pdfflushobject(negative)))
    adddocumentextgstate("GSpositive", pdfreference(pdfflushobject(positive)))
    initializenegative = nil
end

local function initializeoverprint()
    local g = pdfconstant("ExtGState")
    local knockout  = pdfdictionary { Type = g, OP = false, OPM  = 0 }
    local overprint = pdfdictionary { Type = g, OP = true,  OPM  = 1 }
    adddocumentextgstate("GSknockout",  pdfreference(pdfflushobject(knockout)))
    adddocumentextgstate("GSoverprint", pdfreference(pdfflushobject(overprint)))
    initializeoverprint = nil
end

function nodeinjections.overprint()
    if initializeoverprint then initializeoverprint() end
    return copy_node(overprint)
end
function nodeinjections.knockout ()
    if initializeoverprint then initializeoverprint() end
    return copy_node(knockout)
end

function nodeinjections.positive()
    if initializenegative then initializenegative() end
    return copy_node(positive)
end
function nodeinjections.negative()
    if initializenegative then initializenegative() end
    return copy_node(negative)
end

-- function codeinjections.addtransparencygroup()
--     -- png: /CS /DeviceRGB /I true
--     local d = pdfdictionary {
--         S = pdfconstant("Transparency"),
--         I = true,
--         K = true,
--     }
--     lpdf.registerpagefinalizer(function() addtopageattributes("Group",d) end) -- hm
-- end

-- actions (todo: store and update when changed)

local openpage, closepage, opendocument, closedocument

function codeinjections.registerdocumentopenaction(open)
    opendocument = open
end

function codeinjections.registerdocumentcloseaction(close)
    closedocument = close
end

function codeinjections.registerpageopenaction(open)
    openpage = open
end

function codeinjections.registerpagecloseaction(close)
    closepage = close
end

local function flushdocumentactions()
    if opendocument then
        addtocatalog("OpenAction",pdfaction(opendocument))
    end
    if closedocument then
        addtocatalog("CloseAction",pdfaction(closedocument))
    end
end

local function flushpageactions()
    if openpage or closepage then
        local d = pdfdictionary()
        if openpage then
            d.O = pdfaction(openpage)
        end
        if closepage then
            d.C = pdfaction(closepage)
        end
        addtopageattributes("AA",d)
    end
end

lpdf.registerpagefinalizer    (flushpageactions,    "page actions")
lpdf.registerdocumentfinalizer(flushdocumentactions,"document actions")

--- info : this can change and move elsewhere

local identity = { }

function codeinjections.setupidentity(specification)
    for k, v in next, specification do
        if v ~= "" then
            identity[k] = v
        end
    end
end

local done = false  -- using "setupidentity = function() end" fails as the meaning is frozen in register

local function setupidentity()
    if not done then
        local title = identity.title
        if not title or title == "" then
            title = tex.jobname
        end
        addtoinfo("Title", pdfunicode(title), title)
        local subtitle = identity.subtitle or ""
        if subtitle ~= "" then
            addtoinfo("Subject", pdfunicode(subtitle), subtitle)
        end
        local author = identity.author or ""
        if author ~= "" then
            addtoinfo("Author",  pdfunicode(author), author) -- '/Author' in /Info, 'Creator' in XMP
        end
        local creator = identity.creator or ""
        if creator ~= "" then
            addtoinfo("Creator", pdfunicode(creator), creator) -- '/Creator' in /Info, 'CreatorTool' in XMP
        end
        local currenttimestamp = lpdf.timestamp()
        addtoinfo("CreationDate", pdfstring(formattedtimestamp(currenttimestamp)))
        local date = identity.date or ""
        local pdfdate = formattedtimestamp(date)
        if pdfdate then
            addtoinfo("ModDate", pdfstring(pdfdate), date)
        else
            -- users should enter the date in 2010-01-19T23:27:50+01:00 format
            -- and if not provided that way we use the creation time instead
            addtoinfo("ModDate", pdfstring(formattedtimestamp(currenttimestamp)), currenttimestamp)
        end
        local keywords = identity.keywords or ""
        if keywords ~= "" then
            keywords = gsub(keywords, "[%s,]+", " ")
            addtoinfo("Keywords",pdfunicode(keywords), keywords)
        end
        local id = lpdf.id()
        addtoinfo("ID", pdfstring(id), id) -- needed for pdf/x
        done = true
    else
        -- no need for a message
    end
end

lpdf.registerpagefinalizer(setupidentity,"identity")

-- or when we want to be able to set things after pag e1:
--
-- lpdf.registerdocumentfinalizer(setupidentity,1,"identity")

local function flushjavascripts()
    local t = interactions.javascripts.flushpreambles()
    if #t > 0 then
        local a = pdfarray()
        local pdf_javascript = pdfconstant("JavaScript")
        for i=1,#t do
            local name, script = t[i][1], t[i][2]
            local j = pdfdictionary {
                S  = pdf_javascript,
                JS = pdfreference(pdfflushstreamobject(script)),
            }
            a[#a+1] = pdfstring(name)
            a[#a+1] = pdfreference(pdfflushobject(j))
        end
        addtonames("JavaScript",pdfreference(pdfflushobject(pdfdictionary{ Names = a })))
    end
end

lpdf.registerdocumentfinalizer(flushjavascripts,"javascripts")

-- -- --

local pagespecs = {
    [variables.max]         = { "FullScreen", false, false },
    [variables.bookmark]    = { "UseOutlines", false, false },
    [variables.fit]         = { "UseNone", false, true },
    [variables.doublesided] = { "UseNone", "TwoColumnRight", true },
    [variables.singlesided] = { "UseNone", false, false },
    [variables.default]     = { "UseNone", "auto", false },
    [variables.auto]        = { "UseNone", "auto", false },
    [variables.none]        = { false, false, false },
}

local pagespec, topoffset, leftoffset, height, width, doublesided = "default", 0, 0, 0, 0, false

function codeinjections.setupcanvas(specification)
    local paperheight = specification.paperheight
    local paperwidth  = specification.paperwidth
    local paperdouble = specification.doublesided
    if paperheight then
        texset('global','pdfpageheight',paperheight)
    end
    if paperwidth then
        texset('global','pdfpagewidth',paperwidth)
    end
    pagespec    = specification.mode       or pagespec
    topoffset   = specification.topoffset  or 0
    leftoffset  = specification.leftoffset or 0
    height      = specification.height     or tex.pdfpageheight
    width       = specification.width      or tex.pdfpagewidth
    if paperdouble ~= nil then
        doublesided = paperdouble
    end
end

local function documentspecification()
    local spec = pagespecs[pagespec] or pagespecs[variables.default]
    if spec then
        local mode, layout, fit = spec[1], spec[2], spec[3]
        if layout == variables.auto then
            if doublesided then
                spec = pagespecs[variables.doublesided] -- to be checked voor interfaces
                if spec then
                    mode, layout, fit = spec[1], spec[2], spec[3]
                end
            else
                layout = false
            end
        end
        mode = mode and pdfconstant(mode)
        layout = layout and pdfconstant(layout)
        fit = fit and pdfdictionary { FitWindow = true }
        if layout then
            addtocatalog("PageLayout",layout)
        end
        if mode then
            addtocatalog("PageMode",mode)
        end
        if fit then
            addtocatalog("ViewerPreferences",fit)
        end
        addtoinfo   ("Trapped", pdfconstant("False")) -- '/Trapped' in /Info, 'Trapped' in XMP
        addtocatalog("Version", pdfconstant(format("1.%s",tex.pdfminorversion)))
    end
end

-- temp hack: the mediabox is not under our control and has a precision of 4 digits

local factor = number.dimenfactors.bp

local function boxvalue(n) -- we could share them
    return pdfverbose(formatters["%0.4F"](factor * n))
end

local function pagespecification()
    local pageheight = tex.pdfpageheight
    local box = pdfarray { -- can be cached
        boxvalue(leftoffset),
        boxvalue(pageheight+topoffset-height),
        boxvalue(width-leftoffset),
        boxvalue(pageheight-topoffset),
    }
    addtopageattributes("CropBox",box) -- mandate for rendering
    addtopageattributes("TrimBox",box) -- mandate for pdf/x
 -- addtopageattributes("BleedBox",box)
 -- addtopageattributes("ArtBox",box)
end

lpdf.registerpagefinalizer(pagespecification,"page specification")
lpdf.registerdocumentfinalizer(documentspecification,"document specification")

-- Page Label support ...
--
-- In principle we can also support /P (prefix) as we can just use the verbose form
-- and we can then forget about the /St (start) as we don't care about those few
-- extra bytes due to lack of collapsing. Anyhow, for that we need a stupid prefix
-- variant and that's not on the agenda now.

local map = {
    numbers       = "D",
    Romannumerals = "R",
    romannumerals = "r",
    Characters    = "A",
    characters    = "a",
}

-- local function featurecreep()
--     local pages, lastconversion, list = structures.pages.tobesaved, nil, pdfarray()
--     local getstructureset = structures.sets.get
--     for i=1,#pages do
--         local p = pages[i]
--         if not p then
--             return -- fatal error
--         else
--             local numberdata = p.numberdata
--             if numberdata then
--                 local conversionset = numberdata.conversionset
--                 if conversionset then
--                     local conversion = getstructureset("structure:conversions",p.block,conversionset,1,"numbers")
--                     if conversion ~= lastconversion then
--                         lastconversion = conversion
--                         list[#list+1] = i - 1 -- pdf starts numbering at 0
--                         list[#list+1] = pdfdictionary { S = pdfconstant(map[conversion] or map.numbers) }
--                     end
--                 end
--             end
--             if not lastconversion then
--                 lastconversion = "numbers"
--                 list[#list+1] = i - 1 -- pdf starts numbering at 0
--                 list[#list+1] = pdfdictionary { S = pdfconstant(map.numbers) }
--             end
--         end
--     end
--     addtocatalog("PageLabels", pdfdictionary { Nums = list })
-- end

local function featurecreep()
    local pages        = structures.pages.tobesaved
    local list         = pdfarray()
    local getset       = structures.sets.get
    local stopped      = false
    local oldlabel     = nil
    local olconversion = nil
    for i=1,#pages do
        local p = pages[i]
        if not p then
            return -- fatal error
        end
        local label = p.viewerprefix or ""
        if p.status == v_stop then
            if not stopped then
                list[#list+1] = i - 1 -- pdf starts numbering at 0
                list[#list+1] = pdfdictionary {
                    P = pdfunicode(label),
                }
                stopped = true
            end
            oldlabel      = nil
            oldconversion = nil
            stopped       = false
        else
            local numberdata = p.numberdata
            local conversion = nil
            local number     = p.number
            if numberdata then
                local conversionset = numberdata.conversionset
                if conversionset then
                    conversion = getset("structure:conversions",p.block,conversionset,1,"numbers")
                end
            end
            conversion = conversion and map[conversion] or map.numbers
            if number == 1 or oldlabel ~= label or oldconversion ~= conversion then
                list[#list+1] = i - 1 -- pdf starts numbering at 0
                list[#list+1] = pdfdictionary {
                    S  = pdfconstant(conversion),
                    St = number,
                    P  = label ~= "" and pdfunicode(label) or nil,
                }
            end
            oldlabel      = label
            oldconversion = conversion
            stopped       = false
        end
    end
    addtocatalog("PageLabels", pdfdictionary { Nums = list })
end

lpdf.registerdocumentfinalizer(featurecreep,"featurecreep")
