if not modules then modules = { } end modules ['meta-fnt'] = {
    version   = 1.001,
    comment   = "companion to meta-fnt.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local next = next
local concat     = table.concat
local format     = string.format
local formatters = string.formatters
local chardata   = characters.data
local fontdata   = fonts.hashes.identifiers

local vffonts    = fonts.handlers.vf

local mpfonts    = fonts.mp or { }
fonts.mp         = mpfonts

mpfonts.version  = mpfonts.version or 1.20
mpfonts.inline   = true
mpfonts.cache    = containers.define("fonts", "mp", mpfonts.version, true)

metapost.fonts   = metapost.fonts or { }

local function unicodetoactualtext(...)
    unicodetoactualtext = backends.codeinjections.unicodetoactualtext
    return unicodetoactualtext(...)
end

-- a few glocals

local characters, descriptions = { }, { }
local factor, code, slot, width, height, depth, total, variants, bbox, llx, lly, urx, ury = 100, { }, 0, 0, 0, 0, 0, 0, true, 0, 0, 0, 0

local flusher = {
    startfigure = function(_chr_,_llx_,_lly_,_urx_,_ury_)
        code   = { }
        slot   = _chr_
        llx    = _llx_
        lly    = _lly_
        urx    = _urx_
        ury    = _ury_
        width  = urx - llx
        height = ury
        depth  = -lly
        total  = total + 1
        inline = mpfonts.inline
    end,
    flushfigure = function(t)
        for i=1,#t do
            code[#code+1] = t[i]
        end
    end,
    stopfigure = function()
        local cd = chardata[n]
        local code = unicodetoactualtext(slot,concat(code," ")) or ""
        descriptions[slot] = {
        --  unicode     = slot,
            name        = cd and cd.adobename,
            width       = width * 100,
            height      = height * 100,
            depth       = depth * 100,
            boundingbox = { llx, lly, urx, ury },
        }
        if inline then
            characters[slot] = {
                commands = {
                    { "pdf", "origin", code },
                }
            }
        else
            characters[slot] = {
                commands = {
                    {
                        "image",
                        {
                            stream = code,
                            bbox   = { 0, -depth * 65536, width * 65536, height * 65536 }
                        },
                    },
                }
            }
        end
        code = nil -- no need to keep that
    end
}

local function process(mpxformat,name,instances,scalefactor)
    local filename = resolvers.findfile(name)
    local attributes = filename and lfs.isfile(filename) and lfs.attributes(filename)
    if attributes then
        statistics.starttiming(metapost.fonts)
        scalefactor = scalefactor or 1
        instances = instances or metapost.fonts.instances or 1 -- maybe store in liost too
        local fontname = file.removesuffix(file.basename(name))
        local modification = attributes.modification
        local filesize = attributes.size
        local hash = file.robustname(formatters["%s %05i %03i"](fontname,scalefactor*1000,instances))
        local lists = containers.read(mpfonts.cache,hash)
        if not lists or lists.modification ~= modification or lists.filesize ~= filesize or lists.instances ~= instances or lists.scalefactor ~= scalefactor then
            statistics.starttiming(flusher)
            local data = io.loaddata(filename)
            metapost.reset(mpxformat)
            metapost.setoutercolor(2) -- no outer color and no reset either
            lists = { }
            for i=1,instances do
                characters   = { }
                descriptions = { }
                metapost.process {
                    mpx         = mpxformat,
                    flusher     = flusher,
                    askedfig    = "all",
                 -- incontext   = false,
                    data        = {
                        formatters["randomseed := %s ;"](i*10),
                        formatters["charscale  := %s ;"](scalefactor),
                        data,
                    },
                }
                lists[i] = {
                    characters   = characters,
                    descriptions = descriptions,
                    parameters   = {
                        designsize    = 655360,
                        slant         =      0,
                        space         =    333   * scalefactor,
                        space_stretch =    166.5 * scalefactor,
                        space_shrink  =    111   * scalefactor,
                        x_height      =    431   * scalefactor,
                        quad          =   1000   * scalefactor,
                        extra_space   =      0,
                    },
                    properties  = {
                        name          = formatters["%s-%03i"](hash,i),
                        virtualized   = true,
                        spacer        = "space",
                    }
                }
            end
            lists.version = metapost.variables.fontversion or "1.000"
            lists.modification = modification
            lists.filesize = filesize
            lists.instances = instances
            lists.scalefactor = scalefactor
            metapost.reset(mpxformat) -- saves memory
            lists = containers.write(mpfonts.cache, hash, lists)
            statistics.stoptiming(flusher)
        end
        variants = variants + #lists
        statistics.stoptiming(metapost.fonts)
        return lists
    else
        return { }
    end
end

metapost.fonts.flusher   = flusher
metapost.fonts.instances = 1
metapost.fonts.process   = process

local function build(g,v)
    local size = g.specification.size
    local data = process(v[2],v[3],v[4],size/655360,v[6])
    local list = { }
    local t = { }
    for d=1,#data do
        t = fonts.constructors.scale(data[d],-1000)
     -- local id = font.nextid()
     -- t.fonts = { { id = id } }
        fontdata[id] = t
        if v[5] then
            vffonts.helpers.composecharacters(t)
        end
        list[d] = font.define(t)
    end
    for k, v in next, t do -- last t
        g[k] = v -- kind of replace, when not present, make nil
    end
    g.properties.virtualized = true
    g.variants = list
end

vffonts.combiner.commands.metapost = build
vffonts.combiner.commands.metafont = build

statistics.register("metapost font generation", function()
    if total > 0 then
        local time = statistics.elapsedtime(flusher)
        if total > 0 then
            return format("%i glyphs, %s seconds runtime, %.1f glyphs/second", total, time, total/tonumber(time))
        else
            return format("%i glyphs, %s seconds runtime", total, time)
        end
    end
end)

statistics.register("metapost font loading",function()
    if variants > 0 then
        local time = statistics.elapsedtime(metapost.fonts)
        if variants > 0 then
            return format("%s seconds, %i instances, %.3f instances/second", time, variants, variants/tonumber(time))
        else
            return format("%s seconds, %i instances", time, variants)
        end
    end
end)

-- fonts.definers.methods.install( "bidi", {
--     {
--         "metapost",    -- method
--         "metafun",     -- format
--         "fontoeps.mp", -- filename
--         1,             -- instances
--         false,         -- compose
--     },
-- } )

local report = logs.reporter("metapost","fonts")

function metapost.fonts.define(specification)
    local fontname = specification.fontname or ""
    local filename = specification.filename or ""
    local format   = specification.format   or "metafun"
    if fontname == "" then
        report("no fontname given")
        return
    end
    if filename == "" then
        report("no filename given for %a",fontname)
        return
    end
    local fullname = resolvers.findfile(filename)
    if fullname == "" then
        report("unable to locate file %a",filename)
        return
    end
    report("generating font %a using format %a and file %a",fontname,format,filename)
    fonts.definers.methods.install(fontname, {
        {
            specification.engine    or "metapost",
            format,
            filename,
            specification.instances or 1,
            specification.compose   or false,
        },
    } )
end

interfaces.implement {
    name      = "definemetafont",
    actions   = metapost.fonts.define,
    arguments = {
        {
            { "fontname" },
            { "filename" },
        }
    }
}

-- metapost.fonts.define {
--     fontname = "bidi",
--     filename = "bidi-symbols.mp",
-- }
