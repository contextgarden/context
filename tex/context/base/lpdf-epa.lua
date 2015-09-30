if not modules then modules = { } end modules ['lpdf-epa'] = {
    version   = 1.001,
    comment   = "companion to lpdf-epa.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- This is a rather experimental feature and the code will probably
-- change.

local type, tonumber = type, tonumber
local format, gsub, lower = string.format, string.gsub, string.lower
local formatters = string.formatters
local abs = math.abs

----- lpegmatch, lpegpatterns = lpeg.match, lpeg.patterns

local trace_links    = false  trackers.register("figures.links",     function(v) trace_links    = v end)
local trace_outlines = false  trackers.register("figures.outliness", function(v) trace_outlines = v end)

local report_link    = logs.reporter("backend","link")
local report_outline = logs.reporter("backend","outline")

local epdf           = epdf
local backends       = backends
local lpdf           = lpdf
local context        = context

local loadpdffile    = lpdf.epdf.load

local nameonly       = file.nameonly

local variables      = interfaces.variables
local codeinjections = backends.pdf.codeinjections
----- urlescaper     = lpegpatterns.urlescaper
----- utftohigh      = lpegpatterns.utftohigh
local escapetex      = characters.filters.utf.private.escape

local bookmarks      = structures.bookmarks

local maxdimen       = 2^30-1

local layerspec = { -- predefining saves time
    "epdflinks"
}

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
                destination = destination[1] -- array
                if tonumber(destination) then
                    add_link(x,y,w,h,formatters["%s::page(%s)"](filename,destination),"file (page)")
                else
                    add_link(x,y,w,h,formatters["file(%s)"](filename),"file")
                end
            end
        end
    end
end

function codeinjections.mergereferences(specification)
    if figures and not specification then
        specification = figures and figures.current()
        specification = specification and specification.status
    end
    if specification then
        local fullname = specification.fullname
        local document = loadpdffile(fullname) -- costs time
        if document then
            local pagenumber  = specification.page    or 1
            local xscale      = specification.yscale  or 1
            local yscale      = specification.yscale  or 1
            local size        = specification.size    or "crop" -- todo
            local pagedata    = document.pages[pagenumber]
            local annotations = pagedata and pagedata.Annots
            local namespace   = makenamespace(fullname)
            local reference   = namespace .. pagenumber
            if annotations and annotations.n > 0 then
                local mediabox  = pagedata.MediaBox
                local llx       = mediabox[1]
                local lly       = mediabox[2]
                local urx       = mediabox[3]
                local ury       = mediabox[4]
                local width     = xscale * (urx - llx) -- \\overlaywidth, \\overlayheight
                local height    = yscale * (ury - lly) -- \\overlaywidth, \\overlayheight
                context.definelayer( { "epdflinks" }, { height = height.."bp" , width = width.."bp" })
                for i=1,annotations.n do
                    local annotation = annotations[i]
                    if annotation then
                        local subtype   = annotation.Subtype
                        local rectangle = annotation.Rect
                        local a_llx     = rectangle[1]
                        local a_lly     = rectangle[2]
                        local a_urx     = rectangle[3]
                        local a_ury     = rectangle[4]
                        local x         = xscale * (a_llx -   llx)
                        local y         = yscale * (a_lly -   lly)
                        local w         = xscale * (a_urx - a_llx)
                        local h         = yscale * (a_ury - a_lly)
                        if subtype == "Link" then
                            local a = annotation.A
                            if not a then
                                report_link("missing link annotation")
                            elseif w > width or h > height or w < 0 or h < 0 or abs(x) > (maxdimen/2) or abs(y) > (maxdimen/2) then
                                report_link("broken link rectangle [%f %f %f %f] (max: %f)",a_llx,a_lly,a_urx,a_ury,maxdimen/2)
                            else
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
                        elseif trace_links then
                            report_link("unsupported annotation %a",subtype)
                        end
                    elseif trace_links then
                        report_link("broken annotation, index %a",i)
                    end
                end
                context.flushlayer { "epdflinks" }
            end
            -- moved outside previous test
            context.setgvalue("figurereference",reference) -- global
            if trace_links then
                report_link("setting figure reference to %a",reference)
            end
            specification.reference = reference
            return namespace
        end
    end
    return ""-- no namespace, empty, not nil
end

function codeinjections.mergeviewerlayers(specification)
    -- todo: parse included page for layers .. or only for whole document inclusion
    if true then
        return
    end
    if not specification then
        specification = figures and figures.current()
        specification = specification and specification.status
    end
    if specification then
        local fullname = specification.fullname
        local document = loadpdffile(fullname)
        if document then
            local namespace = makenamespace(fullname)
            local layers = document.layers
            if layers then
                for i=1,layers.n do
                    local layer = layers[i]
                    if layer then
                        local tag = namespace .. gsub(layer," ",":")
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
    end
end

-- new: for taco

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

    if lfs.isfile(filename) then
        document = loadpdffile(filename)
    else
        report_outline("unknown file %a",filename)
        bookmarks.extras.register(filename,list)
        return list
    end

    local outlines     = document.Catalog.Outlines
    local pages        = document.pages
    local nofpages     = pages.n -- we need to access once in order to initialize
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
                if type(destination) == "string" then
                    entry.destination = destination
                    destination = destinations[destination]
                    local pagedata = destination and destination[1]
                    if pagedata then
                        entry.realpage = pagedata.number
                    end
                else
                    -- maybe
                end
            else
                -- maybe
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
