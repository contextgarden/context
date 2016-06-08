if not modules then modules = { } end modules ['font-ocl'] = {
    version   = 1.001,
    comment   = "companion to font-otf.lua (context)",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- todo : user list of colors

local formatters = string.formatters

local otf = fonts.handlers.otf

local f_color_start = formatters["pdf:direct: %f %f %f rg"]
local s_color_stop  = "pdf:direct:"

local function actualtexthandlers()
    local startactualtext = nil
    local stopactualtext  = nil
    if context then
        local codeinjections = backends.codeinjections
        if codeinjections then
            startactualtext = codeinjections.startunicodetoactualtext
            stopactualtext  = codeinjections.stopunicodetoactualtext
        end
    end
    if not startactualtext then
        -- let's be nice for generic
        local tounicode = fonts.mappings.tounicode16
        startactualtext = function(n)
            return "/Span << /ActualText <feff" .. tounicode(n) .. "> >> BDC"
        end
        stopactualtext = function(n)
            return "EMC"
        end
    end
    return startactualtext, stopactualtext
end

local function initializecolr(tfmdata,kind,value) -- hm, always value
    if value then
        local palettes = tfmdata.resources.colorpalettes
        if palettes then
            --
            local palette = palettes[tonumber(value) or 1] or palettes[1] or { }
            local classes = #palette
            if classes == 0 then
                return
            end
            --
            local characters   = tfmdata.characters
            local descriptions = tfmdata.descriptions
            local properties   = tfmdata.properties
            local colorvalues  = { }
            --
            properties.virtualized = true
            tfmdata.fonts = {
                { id = 0 }
            }
            --
            local startactualtext, stopactualtext = actualtexthandlers()
            --
            for i=1,classes do
                local p = palette[i]
                colorvalues[i] = { "special", f_color_start(p[1]/255,p[2]/255,p[3]/255) }
            end
            --
            local stop = { "special", "pdf:direct:" .. stopactualtext() .. " Q" }
            --
            for unicode, character in next, characters do
                local description = descriptions[unicode]
                if description then
                    local colorlist = description.colors
                    if colorlist then
                        local w = character.width or 0
                        local s = #colorlist
                        local n = 1
                        local t = {
                            { "special", "pdf:direct: q " .. startactualtext(unicode) }
                        }
                        for i=1,s do
                            local entry = colorlist[i]
                            n = n + 1 t[n] = colorvalues[entry.class]
                            n = n + 1 t[n] = { "char", entry.slot }
                            if s > 1 and i < s and w ~= 0 then
                                n = n + 1 t[n] = { "right", -w }
                            end
                        end
                        n = n + 1 t[n] = stop
                        character.commands = t
                    end
                end
            end
        end
    end
end

fonts.handlers.otf.features.register {
    name         = "colr",
    description  = "color glyphs",
    manipulators = {
        base = initializecolr,
        node = initializecolr,
    }
}

otf.svgenabled = true -- for now, this might change

local report_svg    = logs.reporter("fonts","svg conversion")

local nofpdfstreams = 0
local f_name        = formatters["svg-glyph-%05i"]
local f_stream      = formatters["memstream:///svg-glyph-%05i"]

-- todo: make a plugin

local function svgtopdf(svgshapes)
    local svgfile = "temp-otf-svg-shape.svg"
    local pdffile = "temp-otf-svg-shape.pdf"
    local command = "inkscape " .. svgfile .. " --export-pdf=" .. pdffile
 -- local command = [[python "c:\Users\Hans Hagen\AppData\Roaming\Python\Scripts\cairosvg" -f pdf ]] .. svgfile .. " -o " .. pdffile
    local testrun = false

    local pdfshapes = { }
    local nofshapes = #svgshapes
    report_svg("processing %i svg containers",nofshapes)
    for i=1,nofshapes do
        local entry = svgshapes[i]
        for j=entry.first,entry.last do
            local svg  = xml.convert(entry.data)
            local data = xml.first(svg,"/svg[@id='glyph"..j.."']")
            io.savedata(svgfile,tostring(data))
            report_svg("processing svg shape of glyph %i in container %i",j,i)
            os.execute(command)
            pdfshapes[j] = io.loaddata(pdffile)
        end
        if testrun and i > testrun then
            report_svg("quiting test run")
            break
        end
    end
    os.remove(svgfile)
    return pdfshapes
end

local function savepdfhandler()
    if context then
        local setmemstream = resolvers.setmemstream
        if setmemstream then
            return function(pdf)
                nofpdfstreams = nofpdfstreams + 1
                setmemstream(f_name(nofpdfstreams),pdf)
                return f_stream(nofpdfstreams)
            end
        end
    end
    return function(pdf)
        nofpdfstreams = nofpdfstreams + 1
        local name = f_name(nofpdfstreams)
        io.savedata(name,pdf)
        return name
    end
end

local function initializesvg(tfmdata,kind,value) -- hm, always value
    if value and otf.svgenabled then
        local characters   = tfmdata.characters
        local descriptions = tfmdata.descriptions
        local properties   = tfmdata.properties
        --
        local svg       = properties.svg
        local hash      = svg and svg.hash
        local timestamp = svg and svg.timestamp
        if not hash then
            return
        end
        --
        local pdffile   = containers.read(otf.pdfcache,hash)
        local pdfshapes = pdffile and pdffile.pdfshapes
        if not pdfshapes or pdffile.timestamp ~= timestamp then
            local svgfile   = containers.read(otf.svgcache,hash)
            local svgshapes = svgfile and svgfile.svgshapes
            pdfshapes = svgshapes and svgtopdf(svgshapes) or { }
            containers.write(otf.pdfcache, hash, {
                pdfshapes = pdfshapes,
                timestamp = timestamp,
            })
        end
        if not pdfshapes or not next(pdfshapes) then
            return
        end
        --
        properties.virtualized = true
        tfmdata.fonts = {
            { id = 0 }
        }
        --
        local startactualtext, stopactualtext = actualtexthandlers()
        local savepdf = savepdfhandler()
        --
        local stop = { "special", "pdf:direct:" .. stopactualtext() }
        --
        for unicode, character in next, characters do
            local index = character.index
            if index then
                local pdf = pdfshapes[index]
                if pdf then
                    local filename = savepdf(pdf)
                    character.commands = {
                        { "special", "pdf:direct:" .. startactualtext(unicode) },
                        { "down", character.depth or 0 },
                        { "image", img.new {
                            filename = filename,
                            width    = character.width,
                            height   = character.height or 0,
                            depth    = character.depth or 0,
                        } },
                        stop
                    }
                    character.svg = true
                end
            end
        end
    end
end

fonts.handlers.otf.features.register {
    name         = "svg",
    description  = "svg glyphs",
    manipulators = {
        base = initializesvg,
        node = initializesvg,
    }
}
