if not modules then modules = { } end modules ['font-ogr'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- Here we deal with graphic variants and for now also color support ends up here
-- but that might change. It's lmtx only code.

if not context then
    return
elseif CONTEXTLMTXMODE == 0 then
    return
end

local tostring, tonumber, next = tostring, tonumber, next
local round, max, mod, div = math.round, math.round, math.mod, math.div
local concat, setmetatableindex = table.concat, table.setmetatableindex
local formatters = string.formatters

local otf         = fonts.handlers.otf
local otfregister = otf.features.register
otf.svgenabled    = true
otf.pngenabled    = true

-- Just to remind me ... rewritten around the time this was posted on YT which
-- was also around the 2019 ctx meeting:
--
-- Gavin Harrison - "Threatening War" by The Pineapple Thief
-- https://www.youtube.com/watch?v=ENF9wth4kwM

-- todo: svg color plugin
-- todo: get rid of double cm in svg (tricky as also elsewhere)
-- todo: png offsets (depth)
-- todo: maybe collapse indices so that we have less files (harder to debug)
-- todo: manage (read: assign) font id's in lua so we know in advance

do

    -- This is a prelude to something better but I'm still experimenting.

    local dropins     = { }
    fonts.dropins     = dropins
    local droppedin   = 0
    local identifiers = fonts.hashes.identifiers

    function dropins.nextid()
        droppedin = droppedin - 1
        return droppedin
    end

    function dropins.provide(method,t_tfmdata,indexdata,...)
        droppedin                = dropins.nextid()
        local t_characters       = t_tfmdata.characters
        local t_descriptions     = t_tfmdata.descriptions
        local t_properties       = t_tfmdata.properties
        local d_tfmdata          = setmetatableindex({ },t_tfmdata)
        local d_properties       = setmetatableindex({ },t_properties)
        d_tfmdata.properties     = d_properties
        local d_characters       = setmetatableindex({ },t_characters)
        local d_descriptions     = setmetatableindex({ },t_descriptions)
        d_tfmdata.characters     = d_characters
        d_tfmdata.descriptions   = d_descriptions
        d_properties.instance    = - droppedin -- will become an extra element in the hash
        t_properties.virtualized = true
        identifiers[droppedin]   = d_tfmdata
        local fonts              = t_tfmdata.fonts or { }
        t_tfmdata.fonts          = fonts
        d_properties.format      = "type3"
        d_properties.method      = method
        d_properties.indexdata   = { indexdata, ... } -- can take quite some memory
        local slot               = #fonts + 1
        fonts[slot]              = { id = droppedin }
        return slot, droppedin, d_tfmdata, d_properties
    end

    function dropins.clone(method,tfmdata,shapes,...)
        if method and shapes then
            local characters   = tfmdata.characters
            local descriptions = tfmdata.descriptions
            local droppedin, tfmdrop, dropchars, dropdescs, colrshapes
            local idx  = 255
            local slot = 0
            --
            for k, v in next, characters do
                local index = v.index
                if index then
                    local description = descriptions[k]
                    if description then
                        local shape = shapes[index]
                        if shape then
                            if idx >= 255 then
                                idx = 1
                                colrshapes = { filename = shapes.filename, fixdepth = shapes.fixdepth } -- not needed
                                slot, droppedin, tfmdrop = dropins.provide(method,tfmdata,colrshapes)
                                dropchars = tfmdrop.characters
                                dropdescs = tfmdrop.descriptions
                            else
                                idx = idx + 1
                            end
                            colrshapes[idx] = shape -- so not: description
                            --
-- local helpers            = fonts.helpers
-- local prependcommands    = helpers.prependcommands
-- print(v.commands)
                            v.commands = { { "slot", slot, idx } }
                            -- hack to prevent that type 3 also gets 'use' flags .. todo
                            local c = { commands = false, index = idx, dropin = tfmdata }
                            local d = { index = idx, dropin = tfmdata }
                            setmetatableindex(c,v)
                            setmetatableindex(d,description)
                            dropchars[idx] = c
                            dropdescs[idx] = d
                        end
                    end
                end
            end
        else
            -- error
        end
    end

end

-- This sits here for historcal reasons so for now we keep it here.

local startactualtext = nil
local stopactualtext  = nil

function otf.getactualtext(s)
    if not startactualtext then
        startactualtext = backends.codeinjections.startunicodetoactualtextdirect
        stopactualtext  = backends.codeinjections.stopunicodetoactualtextdirect
    end
    return startactualtext(s), stopactualtext()
end

-- This is also somewhat specific.

local sharedpalettes do

    sharedpalettes = { }

    local colors          = attributes.list[attributes.private('color')] or { }
    local transparencies  = attributes.list[attributes.private('transparency')] or { }

    function otf.registerpalette(name,values)
        sharedpalettes[name] = values
        local color          = lpdf.color
        local transparency   = lpdf.transparency
        local register       = colors.register
        for i=1,#values do
            local v = values[i]
            if v == "textcolor" then
                values[i] = false
            else
                local c = nil
                local t = nil
                if type(v) == "table" then
                    c = register(name,"rgb",
                        max(round((v.r or 0)*255),255)/255,
                        max(round((v.g or 0)*255),255)/255,
                        max(round((v.b or 0)*255),255)/255
                    )
                else
                    c = colors[v]
                    t = transparencies[v]
                end
                if c and t then
                    values[i] = color(1,c) .. " " .. transparency(t)
                elseif c then
                    values[i] = color(1,c)
                elseif t then
                    values[i] = color(1,t)
                end
            end
        end
    end

end

do

    local f_color = formatters["%.3f %.3f %.3f rg"]
    local f_gray  = formatters["%.3f g"]

    local hash = setmetatableindex(function(t,k)
        local v = k
        t[k] = v
        return v
    end)

    local function convert(t,k)
        local v = { }
        for i=1,#k do
            local p = k[i]
            local r, g, b = p[1], p[2], p[3]
            if r == g and g == b then
                v[i] = hash[f_gray(r/255)]
            else
                v[i] = hash[f_color(r/255,g/255,b/255)]
            end
        end
        t[k] = v
        return v
    end

    local function initialize(tfmdata,kind,value) -- we really need the id ... todo
        if value then
            local resources = tfmdata.resources
            local palettes  = resources.colorpalettes
            if palettes then
                --
                local converted = resources.converted
                if not converted then
                    converted = setmetatableindex(convert)
                    resources.converted = converted
                end
                local colorvalues = sharedpalettes[value]
                local default     = false -- so the text color (bad for icon overloads)
                if colorvalues then
                    default = colorvalues[#colorvalues]
                else
                    colorvalues = converted[palettes[tonumber(value) or 1] or palettes[1]] or { }
                end
                local classes = #colorvalues
                if classes == 0 then
                    return
                end
                --
                local characters   = tfmdata.characters
                local descriptions = tfmdata.descriptions
                local droppedin, tfmdrop, dropchars, dropdescs, colrshapes
                local idx  = 255
                local slot = 0
                --
                for k, v in next, characters do
                    local index = v.index
                    if index then
                        local description = descriptions[k]
                        if description then
                            local colorlist = description.colors
                            if colorlist then
                                if idx >= 255 then
                                    idx = 1
                                    colrshapes = { }
                                    slot, droppedin, tfmdrop = fonts.dropins.provide("color",tfmdata,colrshapes,colorvalues)
                                    dropchars = tfmdrop.characters
                                    dropdescs = tfmdrop.descriptions
                                else
                                    idx = idx + 1
                                end
                                --
                                colrshapes[idx] = description
                                -- todo: use extender
                                local u = { "use", 0 }
                                for i=1,#colorlist do
                                    u[i+2] = colorlist[i].slot
                                end
                                v.commands = { u, { "slot", slot, idx } }
                                -- hack to prevent that type 3 also gets 'use' flags .. todo
                                local c = { commands = false, index = idx, dropin = tfmdata }
                                local d = { index = idx, dropin = tfmdata }
                                setmetatableindex(c,v)
                                setmetatableindex(d,description)
                                dropchars[idx] = c
                                dropdescs[idx] = d
                            end
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
            base = initialize,
            node = initialize,
        }
    }

end

do

    local report_svg = logs.reporter("fonts","svg")

    local cached = true  directives.register("fonts.svg.cached", function(v) cached = v end)

    local function initializesvg(tfmdata,kind,value) -- hm, always value
        if value then
            local properties = tfmdata.properties
            local svg        = properties.svg
            local hash       = svg and svg.hash
            local timestamp  = svg and svg.timestamp
            if not hash then
                return
            end
            local shapes   = nil
            local method   = nil
            if cached then
            -- we need a different hash than for mkiv, so we append:
                local pdfhash   = hash .. "-svg"
                local pdffile   = containers.read(otf.pdfcache,pdfhash)
                local pdfshapes = pdffile and pdffile.pdfshapes
                local pdftarget = file.join(otf.pdfcache.writable,file.addsuffix(pdfhash,"pdf"))
                if not pdfshapes or pdffile.timestamp ~= timestamp or not next(pdfshapes) or not lfs.isfile(pdftarget) then
                    local svgfile   = containers.read(otf.svgcache,hash)
                    local svgshapes = svgfile and svgfile.svgshapes
                    pdfshapes = svgshapes and metapost.svgshapestopdf(svgshapes,pdftarget,report_svg,tfmdata.parameters.units) or { }
                    containers.write(otf.pdfcache, pdfhash, {
                        pdfshapes = pdfshapes,
                        timestamp = timestamp,
                    })
                end
                shapes = pdfshapes
                method = "pdf"
            else
                local mpsfile   = containers.read(otf.mpscache,hash)
                local mpsshapes = mpsfile and mpsfile.mpsshapes
                if not mpsshapes or mpsfile.timestamp ~= timestamp or not next(mpsshapes) then
                    local svgfile   = containers.read(otf.svgcache,hash)
                    local svgshapes = svgfile and svgfile.svgshapes
                    -- still suboptimal
                    mpsshapes = svgshapes and metapost.svgshapestomp(svgshapes,report_svg,tfmdata.parameters.units) or { }
                    containers.write(otf.mpscache, hash, {
                        mpsshapes = mpsshapes,
                        timestamp = timestamp,
                    })
                end
                shapes = mpsshapes
                method = "mps"
            end
            if shapes then
                shapes.fixdepth = value == "fixdepth"
                fonts.dropins.clone(method,tfmdata,shapes)
            end
        end
    end

    otfregister {
        name         = "svg",
        description  = "svg glyphs",
        manipulators = {
            base = initializesvg,
            node = initializesvg,
        }
    }

end

do

    -- If this is really critical we can also use a pdf file as cache but I don't expect
    -- png fonts to remain used.

    local report_png = logs.reporter("fonts","png conversion")

    local function initializepng(tfmdata,kind,value) -- hm, always value
        if value then
            local properties = tfmdata.properties
            local png        = properties.png
            local hash       = png and png.hash
            local timestamp  = png and png.timestamp
            if not hash then
                return
            end
            local pngfile    = containers.read(otf.pngcache,hash)
            local pngshapes  = pngfile and pngfile.pngshapes
            if pngshapes then
                fonts.dropins.clone("png",tfmdata,pngshapes)
            end
        end
    end

    otfregister {
        name         = "sbix",
        description  = "sbix glyphs",
        manipulators = {
            base = initializepng,
            node = initializepng,
        }
    }

    otfregister {
        name         = "cblc",
        description  = "cblc glyphs",
        manipulators = {
            base = initializepng,
            node = initializepng,
        }
    }

end
