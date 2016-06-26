if not modules then modules = { } end modules ['font-tfm'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local next, type = next, type
local match = string.match

local trace_defining           = false  trackers.register("fonts.defining", function(v) trace_defining = v end)
local trace_features           = false  trackers.register("tfm.features",   function(v) trace_features = v end)

local report_defining          = logs.reporter("fonts","defining")
local report_tfm               = logs.reporter("fonts","tfm loading")

local findbinfile              = resolvers.findbinfile

local fonts                    = fonts
local handlers                 = fonts.handlers
local readers                  = fonts.readers
local constructors             = fonts.constructors
local encodings                = fonts.encodings

local tfm                      = constructors.handlers.tfm
tfm.version                    = 1.000
tfm.maxnestingdepth            = 5
tfm.maxnestingsize             = 65536*1024

local tfmfeatures              = constructors.features.tfm
----- registertfmfeature       = tfmfeatures.register

constructors.resolvevirtualtoo = false -- wil be set in font-ctx.lua

fonts.formats.tfm              = "type1" -- we need to have at least a value here
fonts.formats.ofm              = "type1" -- we need to have at least a value here

--[[ldx--
<p>The next function encapsulates the standard <l n='tfm'/> loader as
supplied by <l n='luatex'/>.</p>
--ldx]]--

-- this might change: not scaling and then apply features and do scaling in the
-- usual way with dummy descriptions but on the other hand .. we no longer use
-- tfm so why bother

-- ofm directive blocks local path search unless set; btw, in context we
-- don't support ofm files anyway as this format is obsolete

-- we need to deal with nested virtual fonts, but because we load in the
-- frontend we also need to make sure we don't nest too deep (esp when sizes
-- get large)
--
-- (VTITLE Example of a recursion)
-- (MAPFONT D 0 (FONTNAME recurse)(FONTAT D 2))
-- (CHARACTER C A (CHARWD D 1)(CHARHT D 1)(MAP (SETRULE D 1 D 1)))
-- (CHARACTER C B (CHARWD D 2)(CHARHT D 2)(MAP (SETCHAR C A)))
-- (CHARACTER C C (CHARWD D 4)(CHARHT D 4)(MAP (SETCHAR C B)))
--
-- we added the same checks as below to the luatex engine

function tfm.setfeatures(tfmdata,features)
    local okay = constructors.initializefeatures("tfm",tfmdata,features,trace_features,report_tfm)
    if okay then
        return constructors.collectprocessors("tfm",tfmdata,features,trace_features,report_tfm)
    else
        return { } -- will become false
    end
end

function tfm.reencode(tfmdata,specification)
    return tfmdata
end

local depth = { } -- table.setmetatableindex("number")

local function read_from_tfm(specification)
    local filename  = specification.filename
    local size      = specification.size
    depth[filename] = (depth[filename] or 0) + 1
    if trace_defining then
        report_defining("loading tfm file %a at size %s",filename,size)
    end
    local tfmdata = font.read_tfm(filename,size) -- not cached, fast enough
    if tfmdata then

        tfmdata = tfm.reencode(tfmdata,specification) -- not a manipulator, has to come earlier

        local features      = specification.features and specification.features.normal or { }
        local resources     = tfmdata.resources  or { }
        local properties    = tfmdata.properties or { }
        local parameters    = tfmdata.parameters or { }
        local shared        = tfmdata.shared     or { }
        --
        properties.name     = tfmdata.name
        properties.fontname = tfmdata.fontname
        properties.psname   = tfmdata.psname
        properties.filename = specification.filename
        properties.format   = fonts.formats.tfm -- better than nothing
        --
        tfmdata.properties  = properties
        tfmdata.resources   = resources
        tfmdata.parameters  = parameters
        tfmdata.shared      = shared
        --
        shared.rawdata      = { }
        shared.features     = features
        shared.processes    = next(features) and tfm.setfeatures(tfmdata,features) or nil
        --
        parameters.size          = size
        parameters.slant         = parameters.slant          or parameters[1] or 0
        parameters.space         = parameters.space          or parameters[2] or 0
        parameters.space_stretch = parameters.space_stretch  or parameters[3] or 0
        parameters.space_shrink  = parameters.space_shrink   or parameters[4] or 0
        parameters.x_height      = parameters.x_height       or parameters[5] or 0
        parameters.quad          = parameters.quad           or parameters[6] or 0
        parameters.extra_space   = parameters.extra_space    or parameters[7] or 0
        --
        constructors.enhanceparameters(parameters) -- official copies for us
        --
        if constructors.resolvevirtualtoo then
            fonts.loggers.register(tfmdata,file.suffix(filename),specification) -- strange, why here
            local vfname = findbinfile(specification.name, 'ovf')
            if vfname and vfname ~= "" then
                local vfdata = font.read_vf(vfname,size) -- not cached, fast enough
                if vfdata then
                    local chars = tfmdata.characters
                    for k,v in next, vfdata.characters do
                        chars[k].commands = v.commands
                    end
                    properties.virtualized = true
                    tfmdata.fonts = vfdata.fonts
                    tfmdata.type = "virtual" -- else nested calls with cummulative scaling
                    local fontlist = vfdata.fonts
                    local name = file.nameonly(filename)
                    for i=1,#fontlist do
                        local n = fontlist[i].name
                        local s = fontlist[i].size
                        local d = depth[filename]
                        s = constructors.scaled(s,vfdata.designsize)
                        if d > tfm.maxnestingdepth then
                            report_defining("too deeply nested virtual font %a with size %a, max nesting depth %s",n,s,tfm.maxnestingdepth)
                            fontlist[i] = { id = 0 }
                        elseif (d > 1) and (s > tfm.maxnestingsize) then
                            report_defining("virtual font %a exceeds size %s",n,s)
                            fontlist[i] = { id = 0 }
                        else
                            local t, id = fonts.constructors.readanddefine(n,s)
                            fontlist[i] = { id = id }
                        end
                    end
                end
            end
        end
        --
        local allfeatures = tfmdata.shared.features or specification.features.normal
        constructors.applymanipulators("tfm",tfmdata,allfeatures,trace_features,report_tfm)
        if not features.encoding then
            local encoding, filename = match(properties.filename,"^(.-)%-(.*)$") -- context: encoding-name.*
            if filename and encoding and encodings.known and encodings.known[encoding] then
                features.encoding = encoding
            end
        end
        -- let's play safe:
        properties.haskerns     = true
        properties.hasligatures = true
        resources.unicodes      = { }
        resources.lookuptags    = { }
        --
        depth[filename] = depth[filename] - 1
        return tfmdata
    else
        depth[filename] = depth[filename] - 1
    end
end

local function check_tfm(specification,fullname) -- we could split up like afm/otf
    local foundname = findbinfile(fullname, 'tfm') or ""
    if foundname == "" then
        foundname = findbinfile(fullname, 'ofm') or "" -- not needed in context
    end
    if foundname == "" then
        foundname = fonts.names.getfilename(fullname,"tfm") or ""
    end
    if foundname ~= "" then
        specification.filename = foundname
        specification.format   = "ofm"
        return read_from_tfm(specification)
    elseif trace_defining then
        report_defining("loading tfm with name %a fails",specification.name)
    end
end

readers.check_tfm = check_tfm

function readers.tfm(specification)
    local fullname = specification.filename or ""
    if fullname == "" then
        local forced = specification.forced or ""
        if forced ~= "" then
            fullname = specification.name .. "." .. forced
        else
            fullname = specification.name
        end
    end
    return check_tfm(specification,fullname)
end

readers.ofm = readers.tfm

-- bonus for old times sake:

do

    local outfiles = { }

    local tfmcache = table.setmetatableindex(function(t,tfmdata)
        local id = font.define(tfmdata)
        t[tfmdata] = id
        return id
    end)

    local encdone  = table.setmetatableindex("table")

    function tfm.reencode(tfmdata,specification)

        local features = specification.features

        if not features then
            return tfmdata
        end

        local features = features.normal

        if not features then
            return tfmdata
        end

        local tfmfile = file.basename(tfmdata.name)
        local encfile = features.reencode -- or features.enc
        local pfbfile = features.pfbfile  -- or features.pfb
        local bitmap  = features.bitmap   -- or features.pk

        if not encfile then
            return tfmdata
        end

        local pfbfile = outfiles[tfmfile]

        if pfbfile == nil then
            if bitmap then
                pfbfile = false
            elseif type(pfbfile) ~= "string" then
                pfbfile = tfmfile
            end
            if type(pfbfile) == "string" then
                pfbfile = file.addsuffix(pfbfile,"pfb")
                pdf.mapline(tfmfile .. "<" .. pfbfile)
                report_tfm("using type1 shapes from %a for %a",pfbfile,tfmfile)
            else
                report_tfm("using bitmap shapes for %a",tfmfile)
                pfbfile = false -- use bitmap
            end
            outfiles[tfmfile] = pfbfile
        end

        local encoding = false

        if type(encfile) == "string" and encfile ~= "auto" then
            encoding = fonts.encodings.load(file.addsuffix(encfile,"enc"))
            if encoding then
                encoding = encoding.vector
            end
        elseif type(pfbfile) == "string" then
            local pfb = fonts.constructors.handlers.pfb
         -- report_tfm("using encoding from %a",pfbfile)
            if pfb and pfb.loadvector then
                local v, e = pfb.loadvector(pfbfile)
                if e then
                    encoding = e
                end
            end
        end

        if not encoding then
            report_tfm("bad encoding for %a, quitting",tfmfile)
            return tfmdata
        end

        local unicoding  = fonts.encodings.agl and fonts.encodings.agl.unicodes
        local virtualid  = tfmcache[tfmdata]
        local tfmdata    = table.copy(tfmdata) -- good enough for small fonts
        local characters = { }
        local originals  = tfmdata.characters
        local indices    = { }
        local parentfont = { "font", 1 }
        local private    = fonts.constructors.privateoffset
        local reported   = encdone[tfmfile][encfile]

        -- create characters table

        for index, name in table.sortedhash(encoding) do -- predictable order
            local unicode  = unicoding[name]
            local original = originals[index]
            if original then
                if not unicode then
                    unicode = private
                    private = private + 1
                    if not reported then
                        report_tfm("glyph %a in font %a with encoding %a gets unicode %U",name,tfmfile,encfile,unicode)
                    end
                end
                characters[unicode] = original
                indices[index]      = unicode
                original.name       = name -- so one can lookup weird names
                original.commands   = { parentfont, { "char", index } }
            else
                report_tfm("bad index %a in font %a with name %a",index,tfmfile,name)
            end
        end

        encdone[tfmfile][encfile] = true

        -- redo kerns and ligatures

        for k, v in next, characters do
            local kerns = v.kerns
            if kerns then
                local t = { }
                for k, v in next, kerns do
                    local i = indices[k]
                    if i then
                        t[i] = v
                    end
                end
                v.kerns = next(t) and t or nil
            end
            local ligatures = v.ligatures
            if ligatures then
                local t = { }
                for k, v in next, ligatures do
                    local i = indices[k]
                    if i then
                        t[i] = v
                        v.char = indices[v.char]
                    end
                end
                v.ligatures = next(t) and t or nil
            end
        end

        -- wrap up

        tfmdata.fonts      = { { id = virtualid } }
        tfmdata.characters = characters

        return tfmdata
    end

end
