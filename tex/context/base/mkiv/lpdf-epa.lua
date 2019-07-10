if not modules then modules = { } end modules ['lpdf-epa'] = {
    version   = 1.001,
    comment   = "companion to lpdf-epa.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- Links can also have quadpoint

-- embedded files ... not bound to a page

local type, tonumber, next = type, tonumber, next
local format, gsub, lower, find = string.format, string.gsub, string.lower, string.find
local formatters = string.formatters
local concat, merged = table.concat, table.merged
local abs = math.abs
local expandname = file.expandname
local allocate = utilities.storage.allocate
local bor, band = bit32.bor, bit32.band
local isfile = lfs.isfile

local trace_links       = false  trackers.register("figures.links",    function(v) trace_links    = v end)
local trace_comments    = false  trackers.register("figures.comments", function(v) trace_comments = v end)
local trace_fields      = false  trackers.register("figures.fields",   function(v) trace_fields   = v end)
local trace_outlines    = false  trackers.register("figures.outlines", function(v) trace_outlines = v end)

local report_link       = logs.reporter("backend","link")
local report_comment    = logs.reporter("backend","comment")
local report_field      = logs.reporter("backend","field")
local report_outline    = logs.reporter("backend","outline")

local lpdf              = lpdf
local backends          = backends
local context           = context

local nodeinjections    = backends.pdf.nodeinjections

local pdfarray          = lpdf.array
local pdfdictionary     = lpdf.dictionary
local pdfconstant       = lpdf.constant
local pdfreserveobject  = lpdf.reserveobject
local pdfreference      = lpdf.reference

local pdfcopyboolean    = lpdf.copyboolean
local pdfcopyunicode    = lpdf.copyunicode
local pdfcopyarray      = lpdf.copyarray
local pdfcopydictionary = lpdf.copydictionary
local pdfcopynumber     = lpdf.copynumber
local pdfcopyinteger    = lpdf.copyinteger
local pdfcopystring     = lpdf.copystring
local pdfcopyconstant   = lpdf.copyconstant

local createimage       = images.create
local embedimage        = images.embed

local hpack_node        = nodes.hpack

local loadpdffile       = lpdf.epdf.load

local nameonly          = file.nameonly

local variables         = interfaces.variables
local codeinjections    = backends.pdf.codeinjections
----- urlescaper        = lpegpatterns.urlescaper
----- utftohigh         = lpegpatterns.utftohigh
local escapetex         = characters.filters.utf.private.escape

local bookmarks         = structures.bookmarks

local maxdimen          = 0x3FFFFFFF -- 2^30-1

local bpfactor          = number.dimenfactors.bp

local layerspec = {
    "epdfcontent"
}

local getpos = function() getpos = backends.codeinjections.getpos  return getpos () end

local collected = allocate()
local tobesaved = allocate()

local jobembedded = {
    collected = collected,
    tobesaved = tobesaved,
}

job.embedded = jobembedded

local function initializer()
    tobesaved = jobembedded.tobesaved
    collected = jobembedded.collected
end

job.register('job.embedded.collected',tobesaved,initializer)

local function validdocument(specification)
    if figures and not specification then
        specification = figures and figures.current()
        specification = specification and specification.status
    end
    if specification then
        local fullname = specification.fullname
        local expanded = lower(expandname(fullname))
        -- we could add a check for duplicate page insertion
        tobesaved[expanded] = true
        --- but that is messy anyway so we forget about it
        return specification, fullname, loadpdffile(fullname) -- costs time
    end
end

local function getmediasize(specification,pagedata)
    local xscale   = specification.xscale or 1
    local yscale   = specification.yscale or 1
    ----- size     = specification.size   or "crop" -- todo
    local mediabox = pagedata.MediaBox
    local llx      = mediabox[1]
    local lly      = mediabox[2]
    local urx      = mediabox[3]
    local ury      = mediabox[4]
    local width    = xscale * (urx - llx) -- \\overlaywidth, \\overlayheight
    local height   = yscale * (ury - lly) -- \\overlaywidth, \\overlayheight
    return llx, lly, urx, ury, width, height, xscale, yscale
end

local function getdimensions(annotation,llx,lly,xscale,yscale,width,height,report)
    local rectangle = annotation.Rect
    local a_llx     = rectangle[1]
    local a_lly     = rectangle[2]
    local a_urx     = rectangle[3]
    local a_ury     = rectangle[4]
    local x         = xscale * (a_llx -   llx)
    local y         = yscale * (a_lly -   lly)
    local w         = xscale * (a_urx - a_llx)
    local h         = yscale * (a_ury - a_lly)
    if w > width or h > height or w < 0 or h < 0 or abs(x) > (maxdimen/2) or abs(y) > (maxdimen/2) then
        report("broken rectangle [%.6F %.6F %.6F %.6F] (max: %.6F)",a_llx,a_lly,a_urx,a_ury,maxdimen/2)
        return
    end
    return x, y, w, h, a_llx, a_lly, a_urx, a_ury
end

local layerused = false

-- local function initializelayer(height,width)
--     if not layerused then
--         context.definelayer(layerspec, { height = height .. "bp", width = width .. "bp" })
--         layerused = true
--     end
-- end

local function initializelayer(height,width)
--     if not layerused then
        context.setuplayer(layerspec, { height = height .. "bp", width = width .. "bp" })
        layerused = true
--     end
end

function codeinjections.flushmergelayer()
    if layerused then
        context.flushlayer(layerspec)
        layerused = false
    end
end

local f_namespace = formatters["lpdf-epa-%s-"]

local function makenamespace(filename)
    filename = gsub(lower(nameonly(filename)),"[^%a%d]+","-")
    return f_namespace(filename)
end

local function add_link(x,y,w,h,destination,what)
    x = x .. "bp"
    y = y .. "bp"
    w = w .. "bp"
    h = h .. "bp"
    if trace_links then
        report_link("destination %a, type %a, dx %s, dy %s, wd %s, ht %s",destination,what,x,y,w,h)
    end
    local locationspec = { -- predefining saves time
        x      = x,
        y      = y,
        preset = "leftbottom",
    }
    local buttonspec = {
        width  = w,
        height = h,
        offset = variables.overlay,
        frame  = trace_links and variables.on or variables.off,
    }
    context.setlayer (
        layerspec,
        locationspec,
        function() context.button ( buttonspec, "", { destination } ) end
     -- context.nested.button(buttonspec, "", { destination }) -- time this
    )
end

local function link_goto(x,y,w,h,document,annotation,pagedata,namespace)
    local a = annotation.A
    if a then
        local destination = a.D -- [ 18 0 R /Fit ]
        local what = "page"
        if type(destination) == "string" then
            local destinations = document.destinations
            local wanted = destinations[destination]
            destination = wanted and wanted.D -- is this ok? isn't it destination already a string?
            if destination then what = "named" end
        end
        local pagedata = destination and destination[1]
        if pagedata then
            local destinationpage = pagedata.number
            if destinationpage then
                add_link(x,y,w,h,namespace .. destinationpage,what)
            end
        end
    end
end

local function link_uri(x,y,w,h,document,annotation)
    local url = annotation.A.URI
    if url then
     -- url = lpegmatch(urlescaper,url)
     -- url = lpegmatch(utftohigh,url)
        url = escapetex(url)
        add_link(x,y,w,h,formatters["url(%s)"](url),"url")
    end
end

-- The rules in PDF on what a 'file specification' is, is in fact quite elaborate
-- (see section 3.10 in the 1.7 reference) so we need to test for string as well
-- as a table. TH/20140916

-- When embedded is set then files need to have page references which is seldom the
-- case but you can generate them with context:
--
-- \setupinteraction[state=start,page={page,page}]
--
-- see tests/mkiv/interaction/cross[1|2|3].tex for an example

local embedded = false directives.register("figures.embedded", function(v) embedded = v end)
local reported = { }

local function link_file(x,y,w,h,document,annotation)
    local a = annotation.A
    if a then
        local filename = a.F
        if type(filename) == "table" then
            filename = filename.F
        end
        if filename then
            filename = escapetex(filename)
            local destination = a.D
            if not destination then
                add_link(x,y,w,h,formatters["file(%s)"](filename),"file")
            elseif type(destination) == "string" then
                add_link(x,y,w,h,formatters["%s::%s"](filename,destination),"file (named)")
            else
                -- hm, zero offset so maybe: destination + 1
                destination = tonumber(destination[1]) -- array
                if destination then
                    destination = destination + 1
                    local loaded = collected[lower(expandname(filename))]
                    if embedded and loaded then
                        add_link(x,y,w,h,makenamespace(filename) .. destination,what)
                    else
                        if loaded and not reported[filename] then
                            report_link("reference to an also loaded file %a, consider using directive: figures.embedded",filename)
                            reported[filename] = true
                        end
                        add_link(x,y,w,h,formatters["%s::page(%s)"](filename,destination),"file (page)")
                    end
                else
                    add_link(x,y,w,h,formatters["file(%s)"](filename),"file")
                end
            end
        end
    end
end

-- maybe handler per subtype and then one loop but then what about order ...

function codeinjections.mergereferences(specification)
    local specification, fullname, document = validdocument(specification)
    if not document then
        return ""
    end
    local pagenumber  = specification.page or 1
    local pagedata    = document.pages[pagenumber]
    local annotations = pagedata and pagedata.Annots
    local namespace   = makenamespace(fullname)
    local reference   = namespace .. pagenumber
    if annotations and #annotations > 0 then
        local llx, lly, urx, ury, width, height, xscale, yscale = getmediasize(specification,pagedata,xscale,yscale)
        initializelayer(height,width)
        for i=1,#annotations do
            local annotation = annotations[i]
            if annotation then
                if annotation.Subtype == "Link" then
                    local a = annotation.A
                    if not a then
                        local d = annotation.Dest
                        if d then
                            annotation.A = { S = "GoTo", D = d } -- no need for a dict
                        end
                    end
                    if not a then
                        report_link("missing link annotation")
                    else
                        local x, y, w, h = getdimensions(annotation,llx,lly,xscale,yscale,width,height,report_link)
                        if x then
                            local linktype = a.S
                            if linktype == "GoTo" then
                                link_goto(x,y,w,h,document,annotation,pagedata,namespace)
                            elseif linktype == "GoToR" then
                                link_file(x,y,w,h,document,annotation)
                            elseif linktype == "URI" then
                                link_uri(x,y,w,h,document,annotation)
                            elseif trace_links then
                                report_link("unsupported link annotation %a",linktype)
                            end
                        end
                    end
                end
            elseif trace_links then
                report_link("broken annotation, index %a",i)
            end
        end
    end
    -- moved outside previous test
    context.setgvalue("figurereference",reference) -- global, todo: setmacro
    if trace_links then
        report_link("setting figure reference to %a",reference)
    end
    specification.reference = reference
    return namespace
end

function codeinjections.mergeviewerlayers(specification)
    -- todo: parse included page for layers .. or only for whole document inclusion
    if true then
        return
    end
    local specification, fullname, document = validdocument(specification)
    if not document then
        return ""
    end
    local namespace = makenamespace(fullname)
    local layers    = document.layers
    if layers then
        for i=1,#layers do
            local layer = layers[i]
            if layer then
                local tag   = namespace .. gsub(layer," ",":")
                local title = tag
                if trace_links then
                    report_link("using layer %a",tag)
                end
                attributes.viewerlayers.define { -- also does some cleaning
                    tag       = tag, -- todo: #3A or so
                    title     = title,
                    visible   = variables.start,
                    editable  = variables.yes,
                    printable = variables.yes,
                }
                codeinjections.useviewerlayer(tag)
            elseif trace_links then
                report_link("broken layer, index %a",i)
            end
        end
    end
end

-- It took a bit of puzzling and playing around to come to the following
-- implementation. In the end it looks simple but as usual it takes a while
-- to see what the specification (and implementation) boils down to. Lots of
-- shared properties and such. The scaling took some trial and error as
-- viewers differ. I had to extend some low level helpers to make it more
-- comfortable. Hm, the specification is somewhat incomplete as some fields
-- are permitted even if not mentioned so in the end we can share more code.
--
-- If all works ok, we can get rid of some copies which saves time and space.

local commentlike = {
    Text      = "text",
    FreeText  = "freetext",
    Line      = "line",
    Square    = "shape",
    Circle    = "shape",
    Polygon   = "poly",
    PolyLine  = "poly",
    Highlight = "markup",
    Underline = "markup",
    Squiggly  = "markup",
    StrikeOut = "markup",
    Caret     = "text",
    Stamp     = "stamp",
    Ink       = "ink",
    Popup     = "popup",
}

local function copyBS(v) -- dict can be shared
    if v then
     -- return pdfdictionary {
     --     Type = copypdfconstant(V.Type),
     --     W    = copypdfnumber  (V.W),
     --     S    = copypdfstring  (V.S),
     --     D    = copypdfarray   (V.D),
     -- }
        return copypdfdictionary(v)
    end
end

local function copyBE(v) -- dict can be shared
    if v then
     -- return pdfdictionary {
     --     S = copypdfstring(V.S),
     --     I = copypdfnumber(V.I),
     -- }
        return copypdfdictionary(v)
    end
end

local function copyBorder(v) -- dict can be shared
    if v then
        -- todo
        return copypdfarray(v)
    end
end

local function copyPopup(v,references)
    if v then
        local p = references[v]
        if p then
            return pdfreference(p)
        end
    end
end

local function copyParent(v,references)
    if v then
        local p = references[v]
        if p then
            return pdfreference(p)
        end
    end
end

local function copyIRT(v,references)
    if v then
        local p = references[v]
        if p then
            return pdfreference(p)
        end
    end
end

local function copyC(v)
    if v then
        -- todo: check color space
        return pdfcopyarray(v)
    end
end

local function finalizer(d,xscale,yscale,a_llx,a_ury)
    local q = d.QuadPoints or d.Vertices or d.CL
    if q then
        return function()
            local h, v = pdfgetpos() -- already scaled
            for i=1,#q,2 do
                q[i]   = xscale * q[i]   + (h*bpfactor - xscale * a_llx)
                q[i+1] = yscale * q[i+1] + (v*bpfactor - yscale * a_ury)
            end
            return d()
        end
    end
    q = d.InkList or d.Path
    if q then
        return function()
            local h, v = pdfgetpos() -- already scaled
            for i=1,#q do
                local q = q[i]
                for i=1,#q,2 do
                    q[i]   = xscale * q[i]   + (h*bpfactor - xscale * a_llx)
                    q[i+1] = yscale * q[i+1] + (v*bpfactor - yscale * a_ury)
                end
            end
            return d()
        end
    end
    return d()
end

local validstamps = {
    Approved            = true,
    Experimental        = true,
    NotApproved         = true,
    AsIs                = true,
    Expired             = true,
    NotForPublicRelease = true,
    Confidential        = true,
    Final               = true,
    Sold                = true,
    Departmental        = true,
    ForComment          = true,
    TopSecret           = true,
    Draft               = true,
    ForPublicRelease    = true,
}

-- todo: we can use runtoks instead of steps

local function validStamp(v)
    local name = "Stamped" -- fallback
    if v then
        local ok = validstamps[v]
        if ok then
            name = ok
        else
            for k in next, validstamps do
                if find(v,k.."$") then
                    name = k
                    validstamps[v] = k
                    break
                end
            end
        end
    end
    -- we temporary return to \TEX:
    context.predefinesymbol { name }
    context.step()
    -- beware, an error is not reported
    return pdfconstant(name), codeinjections.analyzenormalsymbol(name)
end

local annotationflags = lpdf.flags.annotations

local function copyF(v,lock) -- todo: bxor 24
    if lock then
        v = bor(v or 0,annotationflags.ReadOnly + annotationflags.Locked + annotationflags.LockedContents)
    end
    if v then
        return pdfcopyinteger(v)
    end
end

-- Speed is not really an issue so we don't optimize this code too much. In the end (after
-- testing we end up with less code that we started with.

function codeinjections.mergecomments(specification)
    local specification, fullname, document = validdocument(specification)
    if not document then
        return ""
    end
    local pagenumber  = specification.page or 1
    local pagedata    = document.pages[pagenumber]
    local annotations = pagedata and pagedata.Annots
    if annotations and #annotations > 0 then
        local llx, lly, urx, ury, width, height, xscale, yscale = getmediasize(specification,pagedata,xscale,yscale)
        initializelayer(height,width)
        --
        local lockflags  = specification.lock -- todo: proper parameter
        local references = { }
        local usedpopups = { }
        for i=1,#annotations do
            local annotation = annotations[i]
            if annotation then
                local subtype = annotation.Subtype
                if commentlike[subtype] then
                    references[annotation] = pdfreserveobject()
                    local p = annotation.Popup
                    if p then
                        usedpopups[p] = true
                    end
                end
            end
        end
        --
        for i=1,#annotations do
            -- we keep the order
            local annotation = annotations[i]
            if annotation then
                local reference = references[annotation]
                if reference then
                    local subtype = annotation.Subtype
                    local kind    = commentlike[subtype]
                    if kind ~= "popup" or usedpopups[annotation] then
                        local x, y, w, h, a_llx, a_lly, a_urx, a_ury = getdimensions(annotation,llx,lly,xscale,yscale,width,height,report_comment)
                        if x then
                            local voffset    = h
                            local dictionary = pdfdictionary {
                                Subtype      = pdfconstant   (subtype),
                                -- common (skipped: P AP AS OC AF BM StructParent)
                                Contents     = pdfcopyunicode(annotation.Contents),
                                NM           = pdfcopystring (annotation.NM),
                                M            = pdfcopystring (annotation.M),
                                F            = copyF         (annotation.F,lockflags),
                                C            = copyC         (annotation.C),
                                ca           = pdfcopynumber (annotation.ca),
                                CA           = pdfcopynumber (annotation.CA),
                                Lang         = pdfcopystring (annotation.Lang),
                                -- also common
                                CreationDate = pdfcopystring (annotation.CreationDate),
                                T            = pdfcopyunicode(annotation.T),
                                Subj         = pdfcopyunicode(annotation.Subj),
                                -- border
                                Border       = pdfcopyarray  (annotation.Border),
                                BS           = copyBS        (annotation.BS),
                                BE           = copyBE        (annotation.BE),
                                -- sort of common
                                Popup        = copyPopup     (annotation.Popup,references),
                                RC           = pdfcopyunicode(annotation.RC) -- string or stream
                            }
                            if kind == "markup" then
                                dictionary.IRT          = copyIRT          (annotation.IRT,references)
                                dictionary.RT           = pdfconstant      (annotation.RT)
                                dictionary.IT           = pdfcopyconstant  (annotation.IT)
                                dictionary.QuadPoints   = pdfcopyarray     (annotation.QuadPoints)
                             -- dictionary.RD           = pdfcopyarray     (annotation.RD)
                            elseif kind == "text" then
                                -- somehow F fails to view : /F 24 : bit4=nozoom bit5=norotate
                                dictionary.F            = nil
                                dictionary.Open         = pdfcopyboolean   (annotation.Open)
                                dictionary.Name         = pdfcopyunicode   (annotation.Name)
                                dictionary.State        = pdfcopystring    (annotation.State)
                                dictionary.StateModel   = pdfcopystring    (annotation.StateModel)
                                dictionary.IT           = pdfcopyconstant  (annotation.IT)
                                dictionary.QuadPoints   = pdfcopyarray     (annotation.QuadPoints)
                                dictionary.RD           = pdfcopyarray     (annotation.RD) -- caret
                                dictionary.Sy           = pdfcopyconstant  (annotation.Sy) -- caret
                                voffset = 0
                            elseif kind == "freetext" then
                                dictionary.DA           = pdfcopystring    (annotation.DA)
                                dictionary.Q            = pdfcopyinteger   (annotation.Q)
                                dictionary.DS           = pdfcopystring    (annotation.DS)
                                dictionary.CL           = pdfcopyarray     (annotation.CL)
                                dictionary.IT           = pdfcopyconstant  (annotation.IT)
                                dictionary.LE           = pdfcopyconstant  (annotation.LE)
                             -- dictionary.RC           = pdfcopystring    (annotation.RC)
                            elseif kind == "line" then
                                dictionary.LE           = pdfcopyarray     (annotation.LE)
                                dictionary.IC           = pdfcopyarray     (annotation.IC)
                                dictionary.LL           = pdfcopynumber    (annotation.LL)
                                dictionary.LLE          = pdfcopynumber    (annotation.LLE)
                                dictionary.Cap          = pdfcopyboolean   (annotation.Cap)
                                dictionary.IT           = pdfcopyconstant  (annotation.IT)
                                dictionary.LLO          = pdfcopynumber    (annotation.LLO)
                                dictionary.CP           = pdfcopyconstant  (annotation.CP)
                                dictionary.Measure      = pdfcopydictionary(annotation.Measure) -- names
                                dictionary.CO           = pdfcopyarray     (annotation.CO)
                                voffset = 0
                            elseif kind == "shape" then
                                dictionary.IC           = pdfcopyarray     (annotation.IC)
                             -- dictionary.RD           = pdfcopyarray     (annotation.RD)
                                voffset = 0
                            elseif kind == "stamp" then
                                local name, appearance  = validStamp(annotation.Name)
                                dictionary.Name         = name
                                dictionary.AP           = appearance
                                voffset = 0
                            elseif kind == "ink" then
                                dictionary.InkList      = pdfcopyarray     (annotation.InkList)
                            elseif kind == "poly" then
                                dictionary.Vertices     = pdfcopyarray     (annotation.Vertices)
                             -- dictionary.LE           = pdfcopyarray     (annotation.LE) -- todo: names in array
                                dictionary.IC           = pdfcopyarray     (annotation.IC)
                                dictionary.IT           = pdfcopyconstant  (annotation.IT)
                                dictionary.Measure      = pdfcopydictionary(annotation.Measure)
                                dictionary.Path         = pdfcopyarray     (annotation.Path)
                             -- dictionary.RD           = pdfcopyarray     (annotation.RD)
                            elseif kind == "popup" then
                                dictionary.Open         = pdfcopyboolean   (annotation.Open)
                                dictionary.Parent       = copyParent       (annotation.Parent,references)
                                voffset = 0
                            end
                            if dictionary then
                                local locationspec = {
                                    x       = x .. "bp",
                                    y       = y .. "bp",
                                    voffset = voffset .. "bp",
                                    preset  = "leftbottom",
                                }
                                local finalize = finalizer(dictionary,xscale,yscale,a_llx,a_ury)
                                context.setlayer(layerspec,locationspec,function()
                                    context(hpack_node(nodeinjections.annotation(w/bpfactor,h/bpfactor,0,finalize,reference)))
                                end)
                            end
                        end
                    else
                     -- report_comment("skipping annotation, index %a",i)
                    end
                end
            elseif trace_comments then
                report_comment("broken annotation, index %a",i)
            end
        end
    end
    return namespace
end

local widgetflags = lpdf.flags.widgets

local function flagstoset(flag,flags)
    local t = { }
    if flags then
        for k, v in next, flags do
            if band(flag,v) ~= 0 then
                t[k] = true
            end
        end
    end
    return t
end

-- BS : border style dict
-- R  : rotation 0 90 180 270
-- BG : background array
-- CA : caption string
-- RC : roll over caption
-- AC : down caption
-- I/RI/IX : icon streams
-- IF      : fit dictionary
-- TP      : text position number

-- Opt : array of texts
-- TI  : top index

-- V  : value
-- DV : default value
-- DS : default string
-- RV : rich
-- Q  : quadding (0=left 1=middle 2=right)

function codeinjections.mergefields(specification)
    local specification, fullname, document = validdocument(specification)
    if not document then
        return ""
    end
    local pagenumber  = specification.page or 1
    local pagedata    = document.pages[pagenumber]
    local annotations = pagedata and pagedata.Annots
    if annotations and #annotations > 0 then
        local llx, lly, urx, ury, width, height, xscale, yscale = getmediasize(specification,pagedata,xscale,yscale)
        initializelayer(height,width)
        --
        for i=1,#annotations do
            -- we keep the order
            local annotation = annotations[i]
            if annotation then
                local subtype = annotation.Subtype
                if subtype == "Widget" then
                    local parent = annotation.Parent or { }
                    local name   = annotation.T or parent.T
                    local what   = annotation.FT or parent.FT
                    if name and what then
                        local x, y, w, h, a_llx, a_lly, a_urx, a_ury = getdimensions(annotation,llx,lly,xscale,yscale,width,height,report_field)
                        if x then
                            x = x .. "bp"
                            y = y .. "bp"
                            local W, H = w, h
                            w = w .. "bp"
                            h = h .. "bp"
                            if trace_fields then
                                report_field("field %a, type %a, dx %s, dy %s, wd %s, ht %s",name,what,x,y,w,h)
                            end
                            local locationspec = {
                                x      = x,
                                y      = y,
                                preset = "leftbottom",
                            }
                            --
                            local aflags = flagstoset(annotation.F or parent.F, annotationflags)
                            local wflags = flagstoset(annotation.Ff or parent.Ff, widgetflags)
                            if what == "Tx" then
                                -- DA DV F FT MaxLen MK Q T V | AA OC
                                if wflags.MultiLine then
                                    wflags.MultiLine = nil
                                    what = "text"
                                else
                                    what = "line"
                                end
                                -- via context
                                local fieldspec = {
                                    width  = w,
                                    height = h,
                                    offset = variables.overlay,
                                    frame  = trace_links and variables.on or variables.off,
                                    n      = annotation.MaxLen or (parent and parent.MaxLen),
                                    type   = what,
                                    option = concat(merged(aflags,wflags),","),
                                }
                                context.setlayer (layerspec,locationspec,function()
                                    context.definefieldbody ( { name } , fieldspec )
                                    context.fieldbody ( { name } )
                                end)
                                --
                            elseif what == "Btn" then
                                if wflags.Radio or wflags.RadiosInUnison then
                                    -- AP AS DA F Ff FT H MK T V | AA OC
                                    wflags.Radio = nil
                                    wflags.RadiosInUnison = nil
                                    what = "radio"
                                elseif wflags.PushButton then
                                    -- AP DA F Ff FT H MK T | AA OC
                                    --
                                    -- Push buttons only have an appearance and some associated
                                    -- actions so they are not worth copying.
                                    --
                                    wflags.PushButton = nil
                                    what = "push"
                                else
                                    -- AP AS DA F Ff FT H MK T V | OC AA
                                    what = "check"
                                    -- direct
                                    local AP = annotation.AP or (parent and parent.AP)
                                    if AP then
                                        local a = document.__xrefs__[AP]
                                        if a and pdfe.copyappearance then
                                            local o = pdfe.copyappearance(document,a)
                                            if o then
                                                AP = pdfreference(o)
                                            end
                                        end
                                    end
                                    local dictionary = pdfdictionary {
                                        Subtype = pdfconstant("Widget"),
                                        FT      = pdfconstant("Btn"),
                                        T       = pdfcopyunicode(annotation.T or parent.T),
                                        F       = pdfcopyinteger(annotation.F or parent.F),
                                        Ff      = pdfcopyinteger(annotation.Ff or parent.Ff),
                                        AS      = pdfcopyconstant(annotation.AS or (parent and parent.AS)),
                                        AP      = AP and pdfreference(AP),
                                    }
                                    local finalize = dictionary()
                                    context.setlayer(layerspec,locationspec,function()
                                        context(hpack_node(nodeinjections.annotation(W/bpfactor,H/bpfactor,0,finalize)))
                                    end)
                                    --
                                end
                            elseif what == "Ch" then
                                -- F Ff FT Opt T | AA OC (rest follows)
                                if wflags.PopUp then
                                    wflags.PopUp = nil
                                    if wflags.Edit then
                                        wflags.Edit = nil
                                        what = "combo"
                                    else
                                        what = "popup"
                                    end
                                else
                                    what = "choice"
                                end
                            elseif what == "Sig" then
                                what = "signature"
                            else
                                what = nil
                            end
                        end
                    end
                end
            end
        end
    end
end

-- Beware, bookmarks can be in pdfdoc encoding or in unicode. However, in mkiv we
-- write out the strings in unicode (hex). When we read them in, we check for a bom
-- and convert to utf.

function codeinjections.getbookmarks(filename)

    -- The first version built a nested tree and flattened that afterwards ... but I decided
    -- to keep it simple and flat.

    local list = bookmarks.extras.get(filename)

    if list then
        return list
    else
        list = { }
    end

    local document = nil

    if isfile(filename) then
        document = loadpdffile(filename)
    else
        report_outline("unknown file %a",filename)
        bookmarks.extras.register(filename,list)
        return list
    end

    local outlines     = document.Catalog.Outlines
    local pages        = document.pages
    local nofpages     = document.nofpages
    local destinations = document.destinations

    -- I need to check this destination analyzer with the one in annotations .. best share
    -- code (and not it's inconsistent). On the todo list ...

    local function setdestination(current,entry)
        local destination = nil
        local action      = current.A
        if action then
            local subtype = action.S
            if subtype == "GoTo" then
                destination = action.D
                local kind = type(destination)
                if kind == "string" then
                    entry.destination = destination
                    destination = destinations[destination]
                    local pagedata = destination and destination[1]
                    if pagedata then
                        entry.realpage = pagedata.number
                    end
                elseif kind == "table" then
                    local pageref = #destination
                    if pageref then
                        local pagedata = pages[pageref]
                        if pagedata then
                            entry.realpage = pagedata.number
                        end
                    end
                end
         -- elseif subtype then
         --     report("unsupported bookmark action %a",subtype)
            end
        else
            local destination = current.Dest
            if destination then
                if type(destination) == "string" then
                    local wanted = destinations[destination]
                    destination = wanted and wanted.D
                    if destination then
                        entry.destination = destination
                    end
                else
                    local pagedata = destination and destination[1]
                    if pagedata and pagedata.Type == "Page" then
                        entry.realpage =  pagedata.number
                 -- else
                 --     report("unsupported bookmark destination (no page)")
                    end
                end
            end
        end
    end

    local function traverse(current,depth)
        while current do
         -- local title = current.Title
            local title = current("Title") -- can be pdfdoc or unicode
            if title then
                local entry = {
                    level = depth,
                    title = title,
                }
                list[#list+1] = entry
                setdestination(current,entry)
                if trace_outlines then
                    report_outline("%w%s",2*depth,title)
                end
            end
            local first = current.First
            if first then
                local current = first
                while current do
                    local title = current.Title
                    if title and trace_outlines then
                        report_outline("%w%s",2*depth,title)
                    end
                    local entry = {
                        level = depth,
                        title = title,
                    }
                    setdestination(current,entry)
                    list[#list+1] = entry
                    traverse(current.First,depth+1)
                    current = current.Next
                end
            end
            current = current.Next
        end
    end

    if outlines then
        if trace_outlines then
            report_outline("outline of %a:",document.filename)
            report_outline()
        end
        traverse(outlines,0)
        if trace_outlines then
            report_outline()
        end
    elseif trace_outlines then
        report_outline("no outline in %a",document.filename)
    end

    bookmarks.extras.register(filename,list)

    return list

end

function codeinjections.mergebookmarks(specification)
    -- codeinjections.getbookmarks(document)
    if not specification then
        specification = figures and figures.current()
        specification = specification and specification.status
    end
    if specification then
        local fullname  = specification.fullname
        local bookmarks = backends.codeinjections.getbookmarks(fullname)
        local realpage  = tonumber(specification.page) or 1
        for i=1,#bookmarks do
            local b = bookmarks[i]
            if not b.usedpage then
                if b.realpage == realpage then
                    if trace_options then
                        report_outline("using %a at page %a of file %a",b.title,realpage,fullname)
                    end
                    b.usedpage  = true
                    b.section   = structures.sections.currentsectionindex()
                    b.pageindex = specification.pageindex
                end
            end
        end
    end
end

-- A bit more than a placeholder but in the same perspective as
-- inclusion of comments and fields:
--
-- getinfo{ filename = "tt.pdf", metadata = true }
-- getinfo{ filename = "tt.pdf", page = 1, metadata = "xml" }
-- getinfo("tt.pdf")

function codeinjections.getinfo(specification)
    if type(specification) == "string" then
        specification = { filename = specification }
    end
    local filename = specification.filename
    if type(filename) == "string" and isfile(filename) then
        local pdffile = loadpdffile(filename)
        if pdffile then
            local pagenumber = specification.page or 1
            local metadata   = specification.metadata
            local catalog    = pdffile.Catalog
            local info       = pdffile.Info
            local pages      = pdffile.pages
            local nofpages   = pdffile.nofpages
            if metadata then
                local m = catalog.Metadata
                if m then
                    m = m()
                    if metadata == "xml" then
                        metadata = xml.convert(m)
                    else
                        metadata = m
                    end
                else
                    metadata = nil
                end
            else
                metadata = nil
            end
            if pagenumber > nofpages then
                pagenumber = nofpages
            end
            local nobox = { 0, 0, 0, 0 }
            local crop  = nobox
            local media = nobox
            local page  = pages[pagenumber]
            if page then
                crop  = page.CropBox or nobox
                media = page.MediaBox or crop or nobox
            end
            local bbox = crop or media or nobox
            return {
                filename     = filename,
                pdfversion   = tonumber(catalog.Version),
                nofpages     = nofpages,
                title        = info.Title,
                creator      = info.Creator,
                producer     = info.Producer,
                creationdate = info.CreationDate,
                modification = info.ModDate,
                metadata     = metadata,
                width        = bbox[4] - bbox[2],
                height       = bbox[3] - bbox[1],
                cropbox      = { crop[1], crop[2], crop[3], crop[4] },      -- we need access
                mediabox     = { media[1], media[2], media[3], media[4] } , -- we need access
            }
        end
    end
end
