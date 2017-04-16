if not modules then modules = { } end modules ['font-ocl'] = {
    version   = 1.001,
    comment   = "companion to font-otf.lua (context)",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- todo : user list of colors

local tostring, next, format = tostring, next, string.format
local round, max = math.round, math.round
local sortedkeys, sortedhash = table.sortedkeys, table.sortedhash

local formatters = string.formatters
local tounicode  = fonts.mappings.tounicode

local otf        = fonts.handlers.otf

local f_color    = formatters["pdf:direct:%f %f %f rg"]
local f_gray     = formatters["pdf:direct:%f g"]
local s_black    = "pdf:direct:0 g"

if context then

    local startactualtext = nil
    local stopactualtext  = nil

    function otf.getactualtext(s)
        if not startactualtext then
            startactualtext = backends.codeinjections.startunicodetoactualtextdirect
            stopactualtext  = backends.codeinjections.stopunicodetoactualtextdirect
        end
        return startactualtext(s), stopactualtext()
    end

else

    local tounicode = fonts.mappings.tounicode16

    function otf.getactualtext(s)
        return
            "/Span << /ActualText <feff" .. n .. "> >> BDC",
            "EMC"
    end

end

local sharedpalettes = { }

if context then

    local graytorgb = attributes.colors.graytorgb
    local cmyktorgb = attributes.colors.cmyktorgb

    function otf.registerpalette(name,values)
        sharedpalettes[name] = values
        for i=1,#values do
            local v = values[i]
            local r, g, b
            local s = v.s
            if s then
                r, g, b = graytorgb(s)
            else
                local c, m, y, k = v.c, v.m, v.y, v.k
                if c or m or y or k then
                    r, g, b = cmyktorgb(c or 0,m or 0,y or 0,k or 0)
                else
                    r, g, b = v.r, v.g, v.b
                end
            end
            values[i] = {
                max(r and round(r*255) or 0,255),
                max(g and round(g*255) or 0,255),
                max(b and round(b*255) or 0,255)
            }
        end
    end

else -- for generic

    function otf.registerpalette(name,values)
        sharedpalettes[name] = values
        for i=1,#values do
            local v = values[i]
            values[i] = {
                max(round((v.r or 0)*255),255),
                max(round((v.g or 0)*255),255),
                max(round((v.b or 0)*255),255)
            }
        end
    end

end

local function initializecolr(tfmdata,kind,value) -- hm, always value
    if value then
        local palettes = tfmdata.resources.colorpalettes
        if palettes then
            --
            local palette = sharedpalettes[value] or palettes[tonumber(value) or 1] or palettes[1] or { }
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
            for i=1,classes do
                local p = palette[i]
                local r, g, b = p[1], p[2], p[3]
                if r == g and g == b then
                    colorvalues[i] = { "special", f_gray(r/255) }
                else
                    colorvalues[i] = { "special", f_color(r/255,g/255,b/255) }
                end
            end
            --
            local getactualtext = otf.getactualtext
            --
            for unicode, character in next, characters do
                local description = descriptions[unicode]
                if description then
                    local colorlist = description.colors
                    if colorlist then
                        local b, e = getactualtext(tounicode(characters[unicode].unicode or 0xFFFD))
                        local w = character.width or 0
                        local s = #colorlist
                        local t = {
                            -- We need to force page first because otherwise the q's get outside
                            -- the font switch and as a consequence the next character has no font
                            -- set (well, it has: the preceding one). As a consequence these fonts
                            -- are somewhat inefficient as each glyph gets the font set. It's a
                            -- side effect of the fact that a font is handled when a character gets
                            -- flushed.
                         -- { "special", "pdf:page:q" },
                         -- { "special", "pdf:raw:" .. b }
                            -- This seems to be okay too:
                            { "special", "pdf:direct:q " .. b },
                        }
                        local n = #t
                        for i=1,s do
                            local entry = colorlist[i]
                            n = n + 1 t[n] = colorvalues[entry.class] or s_black
                            n = n + 1 t[n] = { "char", entry.slot }
                            if s > 1 and i < s and w ~= 0 then
                                n = n + 1 t[n] = { "right", -w }
                            end
                        end
                     -- n = n + 1 t[n] = { "special", "pdf:page:" .. e }
                     -- n = n + 1 t[n] = { "special", "pdf:raw:Q" }
                        -- This seems to be okay too:
                        n = n + 1 t[n] = { "special", "pdf:direct:" .. e .. " Q"}
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

do

 -- local f_setstream = formatters[ [[io.savedata("svg-glyph-%05i",%q)]] ]
 -- local f_getstream = formatters[ [[svg-glyph-%05i]] ]

 -- function otfsvg.storepdfdata(pdf)
 --     nofstreams = nofstreams + 1
 --     storepdfdata = function(pdf)
 --         nofstreams = nofstreams + 1
 --         return f_setstream(nofstreams,pdf), f_getstream(nofstreams)
 --     end
 -- end

    local nofstreams = 0
    local f_name     = formatters[ [[pdf-glyph-%05i]] ]
    local f_used     = context and formatters[ [[original:///%s]] ] or formatters[ [[%s]] ]
    local hashed     = { }
    local cache      = { }

    function otf.storepdfdata(pdf)
        local done = hashed[pdf]
        if not done then
            nofstreams = nofstreams + 1
            local o, n = epdf.openMemStream(pdf,#pdf,f_name(nofstreams))
            cache[n] = o -- we need to keep in mem
            done = f_used(n)
            hashed[pdf] = done
        end
        return nil, done, nil
    end

 -- maybe more efficient but much slower (and we hash already)
 --
 -- if context then
 --
 --     local storepdfdata = otf.storepdfdata
 --     local initialized  = false
 --
 --     function otf.storepdfdata(pdf)
 --         if not initialized then
 --             if resolvers.setmemstream then
 --                 local f_setstream = formatters[ [[resolvers.setmemstream("pdf-glyph-%05i",%q,true)]] ]
 --                 local f_getstream = formatters[ [[memstream:///pdf-glyph-%05i]] ]
 --                 local f_nilstream = formatters[ [[resolvers.resetmemstream("pdf-glyph-%05i",true)]] ]
 --                 storepdfdata = function(pdf)
 --                     local done  = hashed[pdf]
 --                     local set   = nil
 --                     local reset = nil
 --                     if not done then
 --                         nofstreams = nofstreams + 1
 --                         set   = f_setstream(nofstreams,pdf)
 --                         done  = f_getstream(nofstreams)
 --                         reset = f_nilstream(nofstreams)
 --                         hashed[pdf] = done
 --                     end
 --                     return set, done, reset
 --                 end
 --                 otf.storepdfdata = storepdfdata
 --             end
 --             initialized = true
 --         end
 --         return storepdfdata(pdf)
 --     end
 --
 -- end

end

local function pdftovirtual(tfmdata,pdfshapes,kind) -- kind = sbix|svg
    if not tfmdata or not pdfshapes or not kind then
        return
    end
    --
    local characters = tfmdata.characters
    local properties = tfmdata.properties
    local parameters = tfmdata.parameters
    local hfactor    = parameters.hfactor
    --
    properties.virtualized = true
    --
    tfmdata.fonts = {
        { id = 0 }
    }
        --
    local getactualtext = otf.getactualtext
    local storepdfdata  = otf.storepdfdata
    --
 -- local nop = { "nop" }
    --
    for unicode, character in sortedhash(characters) do  -- sort is nicer for svg
        local index = character.index
        if index then
            local pdf  = pdfshapes[index]
            local typ  = type(pdf)
            local data = nil
            local dx   = nil
            local dy   = nil
            if typ == "table" then
                data = pdf.data
                dx   = pdf.dx or 0
                dy   = pdf.dy or 0
            elseif typ == "string" then
                data = pdf
                dx   = 0
                dy   = 0
            end
            if data then
                local setcode, name, nilcode = storepdfdata(data)
                if name then
                    local bt, et = getactualtext(unicode)
                    local wd = character.width  or 0
                    local ht = character.height or 0
                    local dp = character.depth  or 0
                    character.commands = {
                        { "special", "pdf:direct:" .. bt },
                        { "down", dp + dy * hfactor },
                        { "right", dx * hfactor },
                     -- setcode and { "lua", setcode } or nop,
                        { "image", { filename = name, width = wd, height = ht, depth = dp } },
                     -- nilcode and { "lua", nilcode } or nop,
                        { "special", "pdf:direct:" .. et },
                    }
                    character[kind] = true
                end
            end
        end
    end
end

local otfsvg   = otf.svg or { }
otf.svg         = otfsvg
otf.svgenabled  = true

do

    local report_svg = logs.reporter("fonts","svg conversion")

    local loaddata   = io.loaddata
    local savedata   = io.savedata
    local remove     = os.remove

    if context and xml.convert then

        local xmlconvert = xml.convert
        local xmlfirst   = xml.first

        function otfsvg.filterglyph(entry,index)
            local svg  = xmlconvert(entry.data)
            local root = svg and xmlfirst(svg,"/svg[@id='glyph"..index.."']")
            local data = root and tostring(root)
         -- report_svg("data for glyph %04X: %s",index,data)
            return data
        end

    else

        function otfsvg.filterglyph(entry,index) -- can be overloaded
            return entry.data
        end

    end

    local runner = sandbox and sandbox.registerrunner {
        name     = "otfsvg",
        program  = "inkscape",
        method   = "pipeto",
        template = "--shell > temp-otf-svg-shape.log",
        reporter = report_svg,
    }

    if not runner then
        --
        -- poor mans variant for generic:
        --
        runner = function()
            return io.open("inkscape --shell > temp-otf-svg-shape.log","w")
        end
    end

    function otfsvg.topdf(svgshapes)
        local pdfshapes = { }
        local inkscape  = runner()
        if inkscape then
            local nofshapes   = #svgshapes
            local f_svgfile   = formatters["temp-otf-svg-shape-%i.svg"]
            local f_pdffile   = formatters["temp-otf-svg-shape-%i.pdf"]
            local f_convert   = formatters["%s --export-pdf=%s\n"]
            local filterglyph = otfsvg.filterglyph
            local nofdone     = 0
            report_svg("processing %i svg containers",nofshapes)
            statistics.starttiming()
            for i=1,nofshapes do
                local entry = svgshapes[i]
                for index=entry.first,entry.last do
                    local data = filterglyph(entry,index)
                    if data and data ~= "" then
                        local svgfile = f_svgfile(index)
                        local pdffile = f_pdffile(index)
                        savedata(svgfile,data)
                        inkscape:write(f_convert(svgfile,pdffile))
                        pdfshapes[index] = true
                        nofdone = nofdone + 1
                        if nofdone % 100 == 0 then
                            report_svg("%i shapes processed",nofdone)
                        end
                    end
                end
            end
            inkscape:write("quit\n")
            inkscape:close()
            report_svg("processing %i pdf results",nofshapes)
            for index in next, pdfshapes do
                local svgfile = f_svgfile(index)
                local pdffile = f_pdffile(index)
                pdfshapes[index] = loaddata(pdffile)
                remove(svgfile)
                remove(pdffile)
            end
            statistics.stoptiming()
            if statistics.elapsedseconds then
                report_svg("svg conversion time %s",statistics.elapsedseconds() or "-")
            end
        end
        return pdfshapes
    end

end

local function initializesvg(tfmdata,kind,value) -- hm, always value
    if value and otf.svgenabled then
        local svg       = tfmdata.properties.svg
        local hash      = svg and svg.hash
        local timestamp = svg and svg.timestamp
        if not hash then
            return
        end
        local pdffile   = containers.read(otf.pdfcache,hash)
        local pdfshapes = pdffile and pdffile.pdfshapes
        if not pdfshapes or pdffile.timestamp ~= timestamp then
            local svgfile   = containers.read(otf.svgcache,hash)
            local svgshapes = svgfile and svgfile.svgshapes
            pdfshapes = svgshapes and otfsvg.topdf(svgshapes) or { }
            containers.write(otf.pdfcache, hash, {
                pdfshapes = pdfshapes,
                timestamp = timestamp,
            })
        end
        pdftovirtual(tfmdata,pdfshapes,"svg")
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

-- This can be done differently e.g. with ffi and gm and we can share code anway. Using
-- batchmode in gm is not faster and as it accumulates we would need to flush all
-- individual shapes.

local otfsbix   = otf.sbix or { }
otf.sbix        = otfsbix
otf.sbixenabled = true

do

    -- for now png but also other bitmap formats

    local report_sbix = logs.reporter("fonts","sbix conversion")

    local loaddata   = io.loaddata
    local savedata   = io.savedata
    local remove     = os.remove

    local runner = sandbox and sandbox.registerrunner {
        name     = "otfsbix",
        program  = "gm",
        template = "convert -quality 100 temp-otf-sbix-shape.sbix temp-otf-sbix-shape.pdf > temp-otf-svg-shape.log",
     -- reporter = report_sbix,
    }

    if not runner then
        --
        -- poor mans variant for generic:
        --
        runner = function()
            return os.execute("gm convert -quality 100 temp-otf-sbix-shape.sbix temp-otf-sbix-shape.pdf > temp-otf-svg-shape.log")
        end
    end

    -- Alternatively we can create a single pdf file with -adjoin and then pick up pages from
    -- that file but creating thousands of small files is no fun either.

    function otfsbix.topdf(sbixshapes)
        local pdfshapes  = { }
        local sbixfile   = "temp-otf-sbix-shape.sbix"
        local pdffile    = "temp-otf-sbix-shape.pdf"
        local nofdone    = 0
        local indices    = sortedkeys(sbixshapes) -- can be sparse
        local nofindices = #indices
        report_sbix("processing %i sbix containers",nofindices)
        statistics.starttiming()
        for i=1,nofindices do
            local index = indices[i]
            local entry = sbixshapes[index]
            local data  = entry.data
            local x     = entry.x
            local y     = entry.y
            savedata(sbixfile,data)
            runner()
            pdfshapes[index] = {
                x     = x ~= 0 and x or nil,
                y     = y ~= 0 and y or nil,
                data  = loaddata(pdffile),
            }
            nofdone = nofdone + 1
            if nofdone % 100 == 0 then
                report_sbix("%i shapes processed",nofdone)
            end
        end
        report_sbix("processing %i pdf results",nofindices)
        remove(sbixfile)
        remove(pdffile)
        statistics.stoptiming()
        if statistics.elapsedseconds then
            report_sbix("sbix conversion time %s",statistics.elapsedseconds() or "-")
        end
        return pdfshapes
     -- end
    end

end

local function initializesbix(tfmdata,kind,value) -- hm, always value
    if value and otf.sbixenabled then
        local sbix      = tfmdata.properties.sbix
        local hash      = sbix and sbix.hash
        local timestamp = sbix and sbix.timestamp
        if not hash then
            return
        end
        local pdffile   = containers.read(otf.pdfcache,hash)
        local pdfshapes = pdffile and pdffile.pdfshapes
        if not pdfshapes or pdffile.timestamp ~= timestamp then
            local sbixfile   = containers.read(otf.sbixcache,hash)
            local sbixshapes = sbixfile and sbixfile.sbixshapes
            pdfshapes = sbixshapes and otfsbix.topdf(sbixshapes) or { }
            containers.write(otf.pdfcache, hash, {
                pdfshapes = pdfshapes,
                timestamp = timestamp,
            })
        end
        --
        pdftovirtual(tfmdata,pdfshapes,"sbix")
    end
end

fonts.handlers.otf.features.register {
    name         = "sbix",
    description  = "sbix glyphs",
    manipulators = {
        base = initializesbix,
        node = initializesbix,
    }
}

