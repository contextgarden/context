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
local texset, texget = tex.set, tex.get

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
    [variables.max]         = { mode = "FullScreen",  layout = false,            fit = false, fixed = false, duplex = false },
    [variables.bookmark]    = { mode = "UseOutlines", layout = false,            fit = false, fixed = false, duplex = false },
    [variables.fit]         = { mode = "UseNone",     layout = false,            fit = true,  fixed = false, duplex = false },
    [variables.doublesided] = { mode = "UseNone",     layout = "TwoColumnRight", fit = true,  fixed = false, duplex = false },
    [variables.singlesided] = { mode = "UseNone",     layout = false,            fit = false, fixed = false, duplex = false },
    [variables.default]     = { mode = "UseNone",     layout = "auto",           fit = false, fixed = false, duplex = false },
    [variables.auto]        = { mode = "UseNone",     layout = "auto",           fit = false, fixed = false, duplex = false },
    [variables.none]        = { mode = false,         layout = false,            fit = false, fixed = false, duplex = false },
    -- new
    [variables.fixed]       = { mode = "UseNone",     layout = "auto",           fit = false, fixed = true,  duplex = false }, -- noscale
    [variables.landscape]   = { mode = "UseNone",     layout = "auto",           fit = false, fixed = true,  duplex = "DuplexFlipShortEdge" },
    [variables.portrait]    = { mode = "UseNone",     layout = "auto",           fit = false, fixed = true,  duplex = "DuplexFlipLongEdge" },

}

local pagespec, topoffset, leftoffset, height, width, doublesided = "default", 0, 0, 0, 0, false
local cropoffset, bleedoffset, trimoffset, artoffset = 0, 0, 0, 0

function codeinjections.setupcanvas(specification)
    local paperheight = specification.paperheight
    local paperwidth  = specification.paperwidth
    local paperdouble = specification.doublesided
    if paperheight then
        texset('global','pageheight',paperheight)
    end
    if paperwidth then
        texset('global','pagewidth',paperwidth)
    end
    pagespec    = specification.mode        or pagespec
    topoffset   = specification.topoffset   or 0
    leftoffset  = specification.leftoffset  or 0
    height      = specification.height      or texget("pageheight")
    width       = specification.width       or texget("pagewidth")
    --
    cropoffset  = specification.cropoffset  or 0
    trimoffset  = cropoffset  - (specification.trimoffset  or 0)
    bleedoffset = trimoffset  - (specification.bleedoffset or 0)
    artoffset   = bleedoffset - (specification.artoffset   or 0)
    --
    if paperdouble ~= nil then
        doublesided = paperdouble
    end
end

local function documentspecification()
    if not pagespec or pagespec == "" then
        pagespec = variables.default
    end
 -- local settings = utilities.parsers.settings_to_array(pagespec)
 -- local spec     = pagespecs[variables.default]
 -- for i=1,#settings do
 --     local s = pagespecs[settings[i]]
 --     if s then
 --         for k, v in next, s do
 --             spec[k] = v
 --         end
 --     end
 -- end
    local spec = pagespecs[pagespec] or pagespecs[variables.default]
    if spec.layout == "auto" then
        if doublesided then
            local s = pagespecs[variables.doublesided] -- to be checked voor interfaces
            for k, v in next, s do
                spec[k] = v
            end
        else
            spec.layout = false
        end
    end
    local layout = spec.layout
    local mode   = spec.mode
    local fit    = spec.fit
    local fixed  = spec.fixed
    local duplex = spec.duplex
    if layout then
        addtocatalog("PageLayout",pdfconstant(layout))
    end
    if mode then
        addtocatalog("PageMode",pdfconstant(mode))
    end
    if fit or fixed or duplex then
        addtocatalog("ViewerPreferences",pdfdictionary {
            FitWindow    = fit    and true                or nil,
            PrintScaling = fixed  and pdfconstant("None") or nil,
            Duplex       = duplex and pdfconstant(duplex) or nil,
        })
    end
    addtoinfo   ("Trapped", pdfconstant("False")) -- '/Trapped' in /Info, 'Trapped' in XMP
    addtocatalog("Version", pdfconstant(format("1.%s",pdf.getminorversion())))
end

-- temp hack: the mediabox is not under our control and has a precision of 4 digits

local factor  = number.dimenfactors.bp
local f_value = formatters["%0.4F"]

local function boxvalue(n) -- we could share them
    return pdfverbose(f_value(factor * n))
end

local function pagespecification()
    local llx = leftoffset
    local lly = texget("pageheight") + topoffset - height
    local urx = width - leftoffset
    local ury = texget("pageheight") - topoffset
    -- boxes can be cached
    local function extrabox(WhatBox,offset,always)
        if offset ~= 0 or always then
            addtopageattributes(WhatBox, pdfarray {
                boxvalue(llx + offset),
                boxvalue(lly + offset),
                boxvalue(urx - offset),
                boxvalue(ury - offset),
            })
        end
    end
    extrabox("CropBox",cropoffset,true) -- mandate for rendering
    extrabox("TrimBox",trimoffset,true) -- mandate for pdf/x
    extrabox("BleedBox",bleedoffset)    -- optional
 -- extrabox("ArtBox",artoffset)        -- optional .. unclear what this is meant to do
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
