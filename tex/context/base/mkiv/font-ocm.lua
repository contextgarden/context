if not modules then modules = { } end modules ['font-ocm'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

if not context then
    return
elseif CONTEXTLMTXMODE and CONTEXTLMTXMODE > 0 then
    return
else
 -- Maybe I'll also make a generic variant but for now I just test this in
 -- MkIV. After all, color fonts are not that much used (and generic is for
 -- serious looking articles and books and not for fancy documents using
 -- emoji.) Below is a quick and dirty implementation. Also, it looks like
 -- these features were never used outside context anyway (in spite of being
 -- in generic).
end

local tostring, tonumber, next = tostring, tonumber, next
local round, max = math.round, math.round
local sortedkeys, sortedhash, concat = table.sortedkeys, table.sortedhash, table.concat
local setmetatableindex = table.setmetatableindex
local formatters   = string.formatters

local otf         = fonts.handlers.otf
local otfregister = otf.features.register
local bpfactor    = number.dimenfactors.bp
local typethree   = { }

callback.register("provide_charproc_data",function(action,f,...)
    local registered = typethree[f]
    if registered then
        return registered(action,f,...)
    else
        return 0, 0 -- this will also disable further calls
    end
end)

local defaults = {
    [1] = function() return 0, 0 end,
    [2] = function() return 0, 0 end,
    [3] = function() return 0.001, "" end,
}

local function registeractions(t)
    return {
        [1] = t.preroll or defaults[1],
        [2] = t.collect or defaults[2],
        [3] = t.wrapup  or defaults[3],
    }
end

local function registertypethreeresource(specification,n,o)
    specification.usedobjects["X"..n] = lpdf.reference(o)
end

local function registertypethreefont(specification,n,o)
    specification.usedfonts["F"..n] = lpdf.reference(o)
end

local function typethreeresources(specification)
    local usedobjects = specification.usedobjects
    local usedfonts   = specification.usedfonts
    local resources   = { }
    if next(usedobjects) then
        resources[#resources+1] = "/XObject << " .. usedobjects() .. " >>"
    end
    if next(usedfonts) then
        resources[#resources+1] = "/Font << " .. usedfonts() .. " >>"
    end
 -- resources[#resources+1] = lpdf.collectedresources()
    specification.usedfonts   = nil
    specification.usedobjects = nil
    return concat(resources, " ")
end

local function registerfont(specification,actions)
    specification.usedfonts   = lpdf.dictionary()
    specification.usedobjects = lpdf.dictionary()
    typethree[specification.id] = function(action,f,c)
        return actions[action](specification,f,c)
    end
end

fonts.handlers.typethree = {
    register = function(id,handler)
        -- needed for manual
        if not typethree[id] then
            logs.report("fonts","low level Type3 handler registered for font with id %i",id)
            typethree[id] = handler
        end
    end
}

local initializeoverlay  do

    local f_color         = formatters["%.3f %.3f %.3f rg"]
    local f_gray          = formatters["%.3f g"]
    local sharedpalettes  = { }
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

    local function convert(t,k)
        local v = { }
        for i=1,#k do
            local p = k[i]
            local r, g, b = p[1], p[2], p[3]
            if r == g and g == b then
                v[i] = f_gray(r/255)
            else
                v[i] = f_color(r/255,g/255,b/255)
            end
        end
        t[k] = v
        return v
    end

    -- This is by no means watertight (the id mess) especially because we
    -- don't know it yet. Instead we can just assemble here and avoid the
    -- box approach. I might do that (so then we need to pass fonts and
    -- extra resource entries.

    local f_stream  = formatters["%s 0 d0 %s 0 0 %s 0 %s cm /X%i Do"]
    local fontorder = 0
    local actions   = registeractions {

        preroll = function(specification,f,c)
            local data        = specification.delegated[c]
            local colorlist   = data.colorlist
            local colorvalues = specification.colorvalues
            local default     = specification.default
            local mainid      = specification.mainid
            local t = { "\\typethreefont{", mainid, "}" }
            local n = 3
            local l = nil
            local m = #colorlist
            for i=1,m do
                local entry = colorlist[i]
                local v = colorvalues[entry.class] or default
                if v and l ~= v then
                    n = n + 1 ; t[n] = "\\typethreecode{"
                    n = n + 1 ; t[n] = v
                    n = n + 1 ; t[n] = "}"
                    l = v
                end
                if i < m then
                    n = n + 1 ; t[n] = "\\typethreechar{"
                else
                    n = n + 1 ; t[n] = "\\typethreelast{"
                end
                n = n + 1 ; t[n] = entry.slot
                n = n + 1 ; t[n] = "}"
            end
            token.set_macro("typethreemacro",concat(t))
            tex.runtoks("typethreetoks")
            registertypethreeresource(specification,c,tex.saveboxresource(0,nil,lpdf.collectedresources(),true))
         -- registertypethreefont(specification,mainid,lpdf.reference(lpdf.getfontobjnumber(mainid)))
            return 0, 0
        end,

        collect = function(specification,f,c)
            local parameters = specification.parameters
            local data       = specification.delegated[c]
            local factor     = parameters.hfactor
            local units      = parameters.units
            local width      = (data.width or 0) / factor
            local scale      = 100
            local factor     = units * bpfactor -- / scale
            local depth      = (data.depth or 0)*factor
            local shift      = - depth / (10*units/1000)
            local object     = pdf.immediateobj("stream",f_stream(width,scale,scale,shift,c))
            return object, width
        end,

        wrapup = function(specification,f)
            return 0.001, typethreeresources(specification)
        end,

    }

    local function register(specification)
        registerfont(specification,actions)
    end

    initializeoverlay = function(tfmdata,kind,value)
        if value then
            local resources = tfmdata.resources
            local palettes  = resources.colorpalettes
            if palettes then
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
                local properties   = tfmdata.properties
                local parameters   = tfmdata.parameters
                --
                properties.virtualized = true
                --
                local delegated = { }
                local index     = 0
                local fonts     = tfmdata.fonts or { }
                local fontindex = #fonts + 1
                tfmdata.fonts   = fonts

                local function flush()
                    if index > 0 then
                        fontorder = fontorder + 1
                        local f = {
                            characters = delegated,
                            parameters = parameters,
                            tounicode  = true,
                            format     = "type3",
                            name       = "InternalTypeThreeFont" , -- .. fontorder,
                            psname     = "none",
                        }
                        fonts[fontindex] = {
                            id          = font.define(f),
                            delegated   = delegated,
                            parameters  = parameters,
                            colorvalues = colorvalues,
                            default     = default,
                        }
                    end
                    fontindex = fontindex + 1
                    index     = 0
                    delegated = { }
                end

                for unicode, character in sortedhash(characters) do
                    local description = descriptions[unicode]
                    if description then
                        local colorlist = description.colors
                        if colorlist then
                            if index == 255 then
                                flush()
                            end
                            index = index + 1
                            delegated[index] = {
                                width     = character.width,
                                height    = character.height,
                                depth     = character.depth,
                                tounicode = character.tounicode,
                                colorlist = colorlist,
                            }
                            character.commands = {
                                { "slot", fontindex, index },
                            }
                        end
                    end
                end

                flush()
                local mainid = font.nextid()
                for i=1,#fonts do
                    local f = fonts[i]
                    if f.delegated then
                        f.mainid = mainid
                        register(f)
                    end
                end

                return true
            end
        end
    end

    otfregister {
        name         = "colr",
        description  = "color glyphs",
        manipulators = {
            base = initializeoverlay,
            node = initializeoverlay,
        }
    }

end

do

    local nofstreams = 0
    local f_name     = formatters[ [[pdf-glyph-%05i]] ]
    local f_used     = context and formatters[ [[original:///%s]] ] or formatters[ [[%s]] ]
    local hashed     = { }
    local cache      = { }

    local openpdf = pdfe.new

    function otf.storepdfdata(pdf)
        if pdf then
            local done = hashed[pdf]
            if not done then
                nofstreams = nofstreams + 1
                local f = f_name(nofstreams)
                local n = openpdf(pdf,#pdf,f)
                done = f_used(n)
                hashed[pdf] = done
            end
            return done
        end
    end

end

local pdftovirtual  do

    local f_stream  = formatters["%s 0 d0 %s 0 0 %s %s %s cm /X%i Do"]
    local fontorder = 0
    local shared    = { }
    local actions   = registeractions {

        preroll = function(specification,f,c)
            return 0, 0
        end,

        collect = function(specification,f,c)
            local parameters = specification.parameters
            local data       = specification.delegated[c]
            local desdata    = data.desdata
            local pdfdata    = data.pdfdata
            local width      = desdata.width or 0
            local height     = desdata.height or 0
            local depth      = desdata.depth or 0
            local factor     = parameters.hfactor
            local units      = parameters.units
            local typ        = type(pdfdata)

            local dx         = 0
            local dy         = 0
            local scale      = 1

            if typ == "table" then
                data  = pdfdata.data
                dx    = pdfdata.x or pdfdata.dx or 0
                dy    = pdfdata.y or pdfdata.dy or 0
                scale = pdfdata.scale or 1
            elseif typ == "string" then
                data = pdfdata
                dx   = 0
                dy   = 0
            else
                return 0, 0
            end

            if not data then
                return 0, 0
            end

            local name  = otf.storepdfdata(data)
            local xform = shared[name]

            if not xform then
                xform = images.embed(images.create { filename = name })
                shared[name] = xform
            end

            registertypethreeresource(specification,c,xform.objnum)

            scale = scale * (width / (xform.width * bpfactor))
            dy = - depth + dy
-- dx = 0
-- dy = 0
            local object = pdf.immediateobj("stream",f_stream(width,scale,scale,dx,dy,c)), width

            return object, width
        end,

        wrapup = function(specification,f)
            return 1/specification.parameters.units, typethreeresources(specification)
        end,

    }

    local function register(specification)
        registerfont(specification,actions)
    end

    pdftovirtual = function(tfmdata,pdfshapes,kind) -- kind = png|svg
        if not tfmdata or not pdfshapes or not kind then
            return
        end
        --
        local characters   = tfmdata.characters
        local descriptions = tfmdata.descriptions
        local properties   = tfmdata.properties
        local parameters   = tfmdata.parameters
        local hfactor      = parameters.hfactor
        --
        properties.virtualized = true
        --
        local storepdfdata  = otf.storepdfdata
        --
        local delegated = { }
        local index     = 0
        local fonts     = tfmdata.fonts or { }
        local fontindex = #fonts + 1
        tfmdata.fonts   = fonts

        local function flush()
            if index > 0 then
                fontorder = fontorder + 1
                local f = {
                    characters = delegated,
                    parameters = parameters,
                    tounicode  = true,
                    format     = "type3",
                    name       = "InternalTypeThreeFont" .. fontorder,
                    psname     = "none",
                    size       = parameters.size,
                }
                fonts[fontindex] = {
                    id         = font.define(f),
                    delegated  = delegated,
                    parameters = parameters,
                }
            end
            fontindex = fontindex + 1
            index     = 0
            delegated = { }
        end

        for unicode, character in sortedhash(characters) do
            local idx = character.index
            if idx then
                local pdfdata     = pdfshapes[idx]
                local description = descriptions[unicode]
                if pdfdata and description then
                    if index == 255 then
                        flush()
                    end
                    index = index + 1
                    delegated[index] = {
                        desdata   = description,
                        width     = character.width,
                        height    = character.width,
                        depth     = character.width,
                        tounicode = character.tounicode,
                        pdfdata   = pdfdata,
                    }
                    character.commands = {
                        { "slot", fontindex, index },
                    }
                end
            end
        end
        --
        flush()
        local mainid = font.nextid()
        for i=1,#fonts do
            local f = fonts[i]
            if f.delegated then
                f.mainid = mainid
                register(f)
            end
        end
        --
    end

end

local initializesvg  do

    local otfsvg   = otf.svg or { }
    otf.svg        = otfsvg
    otf.svgenabled = true

    local report_svg = logs.reporter("fonts","svg conversion")

    local loaddata   = io.loaddata
    local savedata   = io.savedata
    local remove     = os.remove

    local xmlconvert = xml.convert
    local xmlfirst   = xml.first

    function otfsvg.filterglyph(entry,index)
        local d = entry.data
        if gzip.compressed(d) then
            d = gzip.decompress(d) or d
        end
        local svg  = xmlconvert(d)
        local root = svg and xmlfirst(svg,"/svg[@id='glyph"..index.."']")
        local data = root and tostring(root)
        return data
    end

    local runner = sandbox and sandbox.registerrunner {
        name     = "otfsvg",
        program  = "inkscape",
        method   = "pipeto",
        template = "--export-area-drawing --shell > temp-otf-svg-shape.log",
        reporter = report_svg,
    }

    if not runner then
        --
        -- poor mans variant for generic:
        --
        runner = function()
            return io.popen("inkscape --export-area-drawing --shell > temp-otf-svg-shape.log","w")
        end
    end

    -- There are svg out there with bad viewBox specifications where shapes lay outside that area,
    -- but trying to correct that didn't work out well enough so I discarded that code. BTW, we
    -- decouple the inskape run and the loading run because inkscape is working in the background
    -- in the files so we need to have unique files.
    --
    -- Because a generic setup can be flawed we need to catch bad inkscape runs which add a bit of
    -- ugly overhead. Bah.

    local new = nil

    local function inkscapeformat(suffix)
        if new == nil then
            new = os.resultof("inkscape --version") or ""
            new = new == "" or not find(new,"Inkscape%s*0")
        end
        return new and "filename" or suffix
    end

    function otfsvg.topdf(svgshapes,tfmdata)
        local pdfshapes = { }
        local inkscape  = runner()
        if inkscape then
         -- local indices      = fonts.getindices(tfmdata)
            local descriptions = tfmdata.descriptions
            local nofshapes    = #svgshapes
            local f_svgfile    = formatters["temp-otf-svg-shape-%i.svg"]
            local f_pdffile    = formatters["temp-otf-svg-shape-%i.pdf"]
            local f_convert    = formatters["%s --export-%s=%s\n"]
            local filterglyph  = otfsvg.filterglyph
            local nofdone      = 0
            local processed    = { }
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
                        inkscape:write(f_convert(svgfile,inkscapeformat("pdf"),pdffile))
                        processed[index] = true
                        nofdone = nofdone + 1
                        if nofdone % 25 == 0 then
                            report_svg("%i shapes submitted",nofdone)
                        end
                    end
                end
            end
            if nofdone % 25 ~= 0 then
                report_svg("%i shapes submitted",nofdone)
            end
            report_svg("processing can be going on for a while")
            inkscape:write("quit\n")
            inkscape:close()
            report_svg("processing %i pdf results",nofshapes)
            for index in next, processed do
                local svgfile = f_svgfile(index)
                local pdffile = f_pdffile(index)
             -- local fntdata = descriptions[indices[index]]
             -- local bounds  = fntdata and fntdata.boundingbox
                local pdfdata = loaddata(pdffile)
                if pdfdata and pdfdata ~= "" then
                    pdfshapes[index] = {
                        data = pdfdata,
                     -- x    = bounds and bounds[1] or 0,
                     -- y    = bounds and bounds[2] or 0,
                    }
                end
                remove(svgfile)
                remove(pdffile)
            end
            local characters = tfmdata.characters
            for k, v in next, characters do
                local d = descriptions[k]
                local i = d.index
                if i then
                    local p = pdfshapes[i]
                    if p then
                        local w = d.width
                        local l = d.boundingbox[1]
                        local r = d.boundingbox[3]
                        p.scale = (r - l) / w
                        p.x     = l
                    end
                end
            end
            if not next(pdfshapes) then
                report_svg("there are no converted shapes, fix your setup")
            end
            statistics.stoptiming()
            if statistics.elapsedseconds then
                report_svg("svg conversion time %s",statistics.elapsedseconds() or "-")
            end
        end
        return pdfshapes
    end

    initializesvg = function(tfmdata,kind,value) -- hm, always value
        if value and otf.svgenabled then
            local svg       = tfmdata.properties.svg
            local hash      = svg and svg.hash
            local timestamp = svg and svg.timestamp
            if not hash then
                return
            end
            local pdffile   = containers.read(otf.pdfcache,hash)
            local pdfshapes = pdffile and pdffile.pdfshapes
            if not pdfshapes or pdffile.timestamp ~= timestamp or not next(pdfshapes) then
                -- the next test tries to catch errors in generic usage but of course can result
                -- in running again and again
                local svgfile   = containers.read(otf.svgcache,hash)
                local svgshapes = svgfile and svgfile.svgshapes
                pdfshapes = svgshapes and otfsvg.topdf(svgshapes,tfmdata,otf.pdfcache.writable,hash) or { }
                containers.write(otf.pdfcache, hash, {
                    pdfshapes = pdfshapes,
                    timestamp = timestamp,
                })
            end
            pdftovirtual(tfmdata,pdfshapes,"svg")
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

-- This can be done differently e.g. with ffi and gm and we can share code anway. Using
-- batchmode in gm is not faster and as it accumulates we would need to flush all
-- individual shapes. But ... in context lmtx (and maybe the backport) we will use
-- a different and more efficient method anyway. I'm still wondering if I should
-- keep color code in generic. Maybe it should be optional.

local initializepng  do

    local otfpng   = otf.png or { }
    otf.png        = otfpng
    otf.pngenabled = true

    local report_png = logs.reporter("fonts","png conversion")

    local loaddata   = io.loaddata
    local savedata   = io.savedata
    local remove     = os.remove

    local runner = sandbox and sandbox.registerrunner {
        name     = "otfpng",
        program  = "gm",
        template = "convert -quality 100 temp-otf-png-shape.png temp-otf-png-shape.pdf > temp-otf-svg-shape.log",
     -- reporter = report_png,
    }

    if not runner then
        --
        -- poor mans variant for generic:
        --
        runner = function()
            return os.execute("gm convert -quality 100 temp-otf-png-shape.png temp-otf-png-shape.pdf > temp-otf-svg-shape.log")
        end
    end

    -- Alternatively we can create a single pdf file with -adjoin and then pick up pages from
    -- that file but creating thousands of small files is no fun either.

    local files       = utilities.files
    local openfile    = files.open
    local closefile   = files.close
    local setposition = files.setposition
    local readstring  = files.readstring

    function otfpng.topdf(pngshapes,filename)
        if pngshapes and filename then
            local pdfshapes  = { }
            local pngfile    = "temp-otf-png-shape.png"
            local pdffile    = "temp-otf-png-shape.pdf"
            local nofdone    = 0
            local indices    = sortedkeys(pngshapes) -- can be sparse
            local nofindices = #indices
            report_png("processing %i png containers",nofindices)
            statistics.starttiming()
            local filehandle = openfile(filename)
            for i=1,nofindices do
                local index  = indices[i]
                local entry  = pngshapes[index]
             -- local data   = entry.data -- or placeholder
                local offset = entry.o
                local size   = entry.s
                local x      = entry.x
                local y      = entry.y
                local data   = nil
                if offset and size then
                    setposition(filehandle,offset)
                    data = readstring(filehandle,size)
                    savedata(pngfile,data)
                    runner()
                    data = loaddata(pdffile)
                end
                pdfshapes[index] = {
--                     x    = x ~= 0 and x or nil,
--                     y    = y ~= 0 and y or nil,
                    data = data,
                }
                nofdone = nofdone + 1
                if nofdone % 100 == 0 then
                    report_png("%i shapes processed",nofdone)
                end
            end
            closefile(filehandle)
            report_png("processing %i pdf results",nofindices)
            remove(pngfile)
            remove(pdffile)
            statistics.stoptiming()
            if statistics.elapsedseconds then
                report_png("png conversion time %s",statistics.elapsedseconds() or "-")
            end
            return pdfshapes
        end
    end

    initializepng = function(tfmdata,kind,value) -- hm, always value
        if value and otf.pngenabled then
            local png       = tfmdata.properties.png
            local hash      = png and png.hash
            local timestamp = png and png.timestamp
            if not hash then
                return
            end
            local pdffile   = containers.read(otf.pdfcache,hash)
            local pdfshapes = pdffile and pdffile.pdfshapes
            if not pdfshapes or pdffile.timestamp ~= timestamp then
                local pngfile   = containers.read(otf.pngcache,hash)
                local filename  = tfmdata.resources.filename
                local pngshapes = pngfile and pngfile.pngshapes
                pdfshapes = pngshapes and otfpng.topdf(pngshapes,filename) or { }
                containers.write(otf.pdfcache, hash, {
                    pdfshapes = pdfshapes,
                    timestamp = timestamp,
                })
            end
            --
            pdftovirtual(tfmdata,pdfshapes,"png")
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

    local function initializecolor(tfmdata,kind,value)
        if value == "auto" then
            return
                initializeoverlay(tfmdata,kind,value) or
                initializesvg    (tfmdata,kind,value) or
                initializepng    (tfmdata,kind,value)
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

-- Old stuff:

do

    local startactualtext = nil
    local stopactualtext  = nil

    function otf.getactualtext(s)
        if not startactualtext then
            startactualtext = backends.codeinjections.startunicodetoactualtextdirect
            stopactualtext  = backends.codeinjections.stopunicodetoactualtextdirect
        end
        return startactualtext(s), stopactualtext()
    end

end

