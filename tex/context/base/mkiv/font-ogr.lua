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

local tostring, tonumber, next, type = tostring, tonumber, next, type
local round, max, mod, div = math.round, math.max, math.mod, math.div
local find = string.find
local concat, setmetatableindex, sortedhash = table.concat, table.setmetatableindex, table.sortedhash
local utfbyte = utf.byte
local formatters = string.formatters
local settings_to_hash_strict, settings_to_array = utilities.parsers.settings_to_hash_strict, utilities.parsers.settings_to_array

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

-- what here and what in backend ...

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

    -- todo: pass specification table instead

    function dropins.provide(method,t_tfmdata,indexdata,...)
        local droppedin          = dropins.nextid()
        local t_characters       = t_tfmdata.characters
        local t_descriptions     = t_tfmdata.descriptions
        local t_properties       = t_tfmdata.properties
        local d_tfmdata          = setmetatableindex({ },t_tfmdata)
        local d_properties       = setmetatableindex({ },t_properties)
        d_tfmdata.properties     = d_properties
        local d_characters       = { } -- setmetatableindex({ },t_characters)   -- hm, index vs unicode
        local d_descriptions     = { } -- setmetatableindex({ },t_descriptions) -- hm, index vs unicode
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

    function dropins.clone(method,tfmdata,shapes,...) -- by index
        if method and shapes then
            local characters   = tfmdata.characters
            local descriptions = tfmdata.descriptions
            local droppedin, tfmdrop, dropchars, dropdescs, colrshapes
            local idx  = 255
            local slot = 0
            for k, v in next, characters do
                local index = v.index
                if index then
                    local description = descriptions[k]
                    if description then
                        local shape = shapes[index]
                        if shape then
                            if idx >= 255 then
                                idx = 1
                                colrshapes = setmetatableindex({ },shapes)
                                slot, droppedin, tfmdrop = dropins.provide(method,tfmdata,colrshapes)
                                dropchars = tfmdrop.characters
                                dropdescs = tfmdrop.descriptions
                            else
                                idx = idx + 1
                            end
                            colrshapes[idx] = shape -- so not: description
                            -- todo: prepend
                            v.commands = { { "slot", slot, idx } }
                            -- hack to prevent that type 3 also gets 'use' flags .. todo
                            local c = { commands = false, index = idx, dropin = tfmdrop }
                            local d = { } -- { index = idx, dropin = tfmdrop }
                            setmetatableindex(c,v)
                            setmetatableindex(d,description)
                            dropchars[idx] = c
                            dropdescs[idx] = d -- not needed
                        end
                    end
                end
            end
        else
            -- error
        end
    end

    function dropins.swap(method,tfmdata,shapes,...) -- by unicode
        if method and shapes then
            local characters   = tfmdata.characters
            local descriptions = tfmdata.descriptions
            local droppedin, tfmdrop, dropchars, dropdescs, colrshapes
            local idx  = 255
            local slot = 0
            -- we can have a variant where shaped are by unicode and not by index
            for k, v in next, characters do
                local description = descriptions[k]
                if description then
                    local shape = shapes[k]
                    if shape then
                        if idx >= 255 then
                            idx = 1
                            colrshapes = setmetatableindex({ },shapes)
                            slot, droppedin, tfmdrop = dropins.provide(method,tfmdata,colrshapes)
                            dropchars = tfmdrop.characters
                            dropdescs = tfmdrop.descriptions
                        else
                            idx = idx + 1
                        end
                        colrshapes[idx] = shape -- so not: description
                        -- todo: prepend
                        v.commands = { { "slot", slot, idx } }
                        -- hack to prevent that type 3 also gets 'use' flags .. todo
                        local c = { commands = false, index = idx, dropin = tfmdrop }
                        local d = { } -- index = idx, dropin = tfmdrop }
                        setmetatableindex(c,v)
                        setmetatableindex(d,description)
                        dropchars[idx] = c
                        dropdescs[idx] = d -- not needed
                    end
                end
            end
        else
            -- error
        end
    end

end

do -- this will move to its own module

    local dropins = fonts.dropins

    local shapes = setmetatableindex(function(t,k)
        local v = {
            glyphs     = { },
            parameters = {
                units = 1000
            },
        }
        t[k] = v
        return v
    end)

    function dropins.registerglyphs(parameters)
        local category = parameters.name
        local target   = shapes[category].parameters
        for k, v in next, parameters do
            if k ~= "glyphs" then
                target[k] = v
            end
        end
    end

    function dropins.registerglyph(parameters)
        local category = parameters.category
        local unicode  = parameters.unicode
        local private  = parameters.private
        local unichar  = parameters.unichar
        if private then
            unicode = fonts.helpers.newprivateslot(private)
        elseif type(unichar) == "string" then
            unicode = utfbyte(unichar)
        else
            local unitype = type(unicode)
            if unitype == "string" then
                local uninumber = tonumber(unicode)
                if uninumber then
                    unicode = round(uninumber)
                else
                    unicode = utfbyte(unicode)
                end
            elseif unitype == "number" then
                unicode = round(unicode)
            end
        end
        if unicode then
            parameters.unicode = unicode
         -- print(category,unicode)
            shapes[category].glyphs[unicode] = parameters
        else
            -- error
        end
    end

 -- local function hascolorspec(t)
 --     if (t.color or "") ~= "" then
 --         return true
 --     elseif (t.fillcolor or "") ~= "" then
 --         return true
 --     elseif (t.drawcolor or "") ~= "" then
 --         return true
 --     elseif (t.linecolor or "") ~= "" then
 --         return true
 --     else
 --         return false
 --     end
 -- end

    local function hascolorspec(t)
        for k, v in next, t do
            if find(k,"color") then
                return true
            end
        end
        return false
    end

    local function initializemps(tfmdata,kind,value)
        if value then
            local specification = settings_to_hash_strict(value)
            if not specification or not next(specification) then
                specification = { category = value }
            end
            -- todo: multiple categories but then maybe also different
            -- clones because of the units .. for now we assume the same
            -- units
            local category = specification.category
            if category and category ~= "" then
                local categories = settings_to_array(category)
                local usedshapes = nil
                local index      = 0
                local spread     = tonumber(specification.spread or 0)
                local hascolor   = hascolorspec(specification)
                specification.spread = spread -- now a number
                for i=1,#categories do
                    local category  = categories[i]
                    local mpsshapes = shapes[category]
                    if mpsshapes then
                        local properties    = tfmdata.properties
                        local parameters    = tfmdata.parameters
                        local characters    = tfmdata.characters
                        local descriptions  = tfmdata.descriptions
                        local mpsparameters = mpsshapes.parameters
                        local units         = mpsparameters.units  or 1000
                        local defaultwidth  = mpsparameters.width  or 0
                        local defaultheight = mpsparameters.height or 0
                        local defaultdepth  = mpsparameters.depth  or 0
                        local usecolor      = mpsparameters.usecolor
                        local spread        = spread * units
                        local defaultcode   = mpsparameters.code or ""
                        local scale         = parameters.size / units
                        if hascolor then
                            -- the graphic has color
                            usecolor = false
                        else
                            -- do whatever is specified
                        end
                        usedshapes = usedshapes or {
                            instance      = "simplefun",
                            units         = units,
                            usecolor      = usecolor,
                            specification = specification,
                            shapes        = mpsshapes,
                        }
                        -- todo: deal with extensibles and more properties
                        for unicode, shape in sortedhash(mpsshapes.glyphs) do
                         -- local oldc = characters[unicode]
                         -- if oldc then
                                index = index + 1 -- todo: somehow we end up with 2 as first entry after 0
                                local wd = shape.width  or defaultwidth
                                local ht = shape.height or defaultheight
                                local dp = shape.depth  or defaultdepth
                                local newc = {
                                    index   = index, -- into usedshapes
                                    width   = scale * (wd + spread),
                                    height  = scale * ht,
                                    depth   = scale * dp,
                                    unicode = unicode,
                                }
                                --
                                characters  [unicode] = newc
                                descriptions[unicode] = newc
                                --
                                usedshapes[unicode] = shape.code or defaultcode
                         -- end
                        end
                    end
                end
                if usedshapes then
                    -- todo: different font when units and usecolor changes, maybe move into loop
                    -- above
                    dropins.swap("mps",tfmdata,usedshapes)
                end
            end
        end
    end

    -- This kicks in quite late, after features have been checked. So if needed
    -- substitutions need to be defined with force.

    otfregister {
        name         = "metapost",
        description  = "metapost glyphs",
        manipulators = {
            base = initializemps,
            node = initializemps,
        }
    }

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

local initializeoverlay  do

    -- we should use the proper interface instead but for now:

    local colors    = attributes.colors
    local rgbtocmyk = colors.rgbtocmyk

    local f_cmyk = formatters["%.3N %.3f %.3N %.3N k"]
    local f_rgb  = formatters["%.3N %.3f %.3N rg"]
    local f_gray = formatters["%.3N g"]

    local function convert(t,k)
        local v = { }
        local m = colors.model
        for i=1,#k do
            local p = k[i]
            local r, g, b = p[1]/255, p[2]/255, p[3]/255
            if r == g and g == b then
                p = f_gray(r)
            elseif m == "cmyk" then
                p = f_cmyk(rgbtocmyk(r,g,b))
            else
                p = f_rgb(r,g,b)
            end
            v[i] = p
        end
        t[k] = v
        return v
    end

    initializeoverlay = function(tfmdata,kind,value) -- we really need the id ... todo
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
                -- todo: delay
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
                                local d = { } -- index = idx, dropin = tfmdrop
                                setmetatableindex(c,v)
                                setmetatableindex(d,description)
                                dropchars[idx] = c
                                dropdescs[idx] = d -- not needed
                            end
                        end
                    end
                end
                return true
            end
        end
    end

    fonts.handlers.otf.features.register {
        name         = "colr",
        description  = "color glyphs",
        manipulators = {
            base = initializeoverlay,
            node = initializeoverlay,
        }
    }

end

local initializesvg  do

    local report_svg = logs.reporter("fonts","svg")

    local cached = true -- maybe always false (after i've optimized the lot)

    directives.register("fonts.svg.cached", function(v) cached = v end)

    initializesvg = function(tfmdata,kind,value) -- hm, always value
        if value then
            local properties = tfmdata.properties
            local svg        = properties.svg
            local hash       = svg and svg.hash
            local timestamp  = svg and svg.timestamp
            if not hash then
                return
            end
            local shapes  = nil
            local method  = nil
            local enforce = attributes.colors.model == "cmyk"
            if cached and not enforce then
             -- we need a different hash than for mkiv, so we append:
                local pdfhash   = hash .. "-svg"
                local pdffile   = containers.read(otf.pdfcache,pdfhash)
                local pdfshapes = pdffile and pdffile.pdfshapes
                local pdftarget = file.join(otf.pdfcache.writable,file.addsuffix(pdfhash,"pdf"))
                if not pdfshapes or pdffile.timestamp ~= timestamp or not next(pdfshapes) or not lfs.isfile(pdftarget) then
                    local svgfile   = containers.read(otf.svgcache,hash)
                    local svgshapes = svgfile and svgfile.svgshapes
                    pdfshapes = svgshapes and metapost.svgshapestopdf(svgshapes,pdftarget,report_svg,tfmdata.parameters.units) or { }
                    -- look at ocl: we should store scale and x and y
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
                    if enforce then
                        -- cheap conversion, no black component generation
                        mpsshapes.preamble = "interim svgforcecmyk := 1;"
                    end
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
            return true
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

local initializepng  do

    -- If this is really critical we can also use a pdf file as cache but I don't expect
    -- png fonts to remain used.

    local colors = attributes.colors

    local report_png = logs.reporter("fonts","png conversion")

    initializepng = function(tfmdata,kind,value) -- hm, always value
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
                if colors.model == "cmyk" then
                    pngshapes.enforcecmyk = true
                end
                fonts.dropins.clone("png",tfmdata,pngshapes)
            end
            return true
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

do

    -- I need to check jpeg and such but will do that when I run into
    -- it.

    local function initializecolor(tfmdata,kind,value)
        if value == "auto" then
            return
                initializeoverlay(tfmdata,kind,value) or
                initializesvg(tfmdata,kind,value) or
                initializepng(tfmdata,kind,value)
        elseif value == "overlay" then
            return initializeoverlay(tfmdata,kind,value)
        elseif value == "svg" then
            return initializesvg(tfmdata,kind,value)
        elseif value == "png" or value == "bitmap" then
            return initializepng(tfmdata,kind,value)
        else
            -- forget about it
        end
    end

    otfregister {
        name         = "color",
        description  = "color glyphs",
        manipulators = {
            base = initializecolor,
            node = initializecolor,
        }
    }

end
