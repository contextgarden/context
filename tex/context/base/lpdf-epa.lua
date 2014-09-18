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
local format, gsub = string.format, string.gsub
local formatters = string.formatters

----- lpegmatch, lpegpatterns = lpeg.match, lpeg.patterns

local trace_links    = false  trackers.register("figures.links", function(v) trace_links = v end)
local report_link    = logs.reporter("backend","merging")

local backends       = backends
local lpdf           = lpdf
local context        = context

local variables      = interfaces.variables
local codeinjections = backends.pdf.codeinjections
----- urlescaper     = lpegpatterns.urlescaper
----- utftohigh      = lpegpatterns.utftohigh
local escapetex      = characters.filters.utf.private.escape

local layerspec = { -- predefining saves time
    "epdflinks"
}

local function makenamespace(filename)
    return format("lpdf-epa-%s-",file.removesuffix(file.basename(filename)))
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
            destination = wanted and wanted.D
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
        local document = lpdf.epdf.load(fullname)
        if document then
            local pagenumber  = specification.page    or 1
            local xscale      = specification.yscale  or 1
            local yscale      = specification.yscale  or 1
            local size        = specification.size    or "crop" -- todo
            local pagedata    = document.pages[pagenumber]
            local annotations = pagedata and pagedata.Annots
            if annotations and annotations.n > 0 then
                local namespace = format("lpdf-epa-%s-",file.removesuffix(file.basename(fullname)))
                local reference = namespace .. pagenumber
                local mediabox = pagedata.MediaBox
                local llx, lly, urx, ury = mediabox[1], mediabox[2], mediabox[3], mediabox[4]
                local width, height = xscale * (urx - llx), yscale * (ury - lly) -- \\overlaywidth, \\overlayheight
                context.definelayer( { "epdflinks" }, { height = height.."bp" , width = width.."bp" })
                for i=1,annotations.n do
                    local annotation = annotations[i]
                    if annotation then
                        local subtype = annotation.Subtype
                        local rectangle = annotation.Rect
                        local a_llx, a_lly, a_urx, a_ury = rectangle[1], rectangle[2], rectangle[3], rectangle[4]
                        local x, y = xscale * (a_llx -   llx), yscale * (a_lly -   lly)
                        local w, h = xscale * (a_urx - a_llx), yscale * (a_ury - a_lly)
                        if subtype  == "Link" then
                            local a = annotation.A
                            if a then
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
                            else
                                report_link("mising link annotation")
                            end
                        elseif trace_links then
                            report_link("unsupported annotation %a",subtype)
                        end
                    elseif trace_links then
                        report_link("broken annotation, index %a",i)
                    end
                end
                context.flushlayer { "epdflinks" }
             -- context("\\gdef\\figurereference{%s}",reference) -- global
                context.setgvalue("figurereference",reference) -- global
                if trace_links then
                    report_link("setting figure reference to %a",reference)
                end
                specification.reference = reference
                return namespace
            end
        end
    end
    return ""-- no namespace, empty, not nil
end

function codeinjections.mergeviewerlayers(specification)
    -- todo: parse included page for layers
    if true then
        return
    end
    if not specification then
        specification = figures and figures.current()
        specification = specification and specification.status
    end
    if specification then
        local fullname = specification.fullname
        local document = lpdf.epdf.load(fullname)
        if document then
            local namespace = format("lpdf:epa:%s:",file.removesuffix(file.basename(fullname)))
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

