if not modules then modules = { } end modules ['font-gds'] = {
    version   = 1.000,
    comment   = "companion to font-gds.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- depends on ctx

local type, next, tonumber = type, next, tonumber
local gmatch, lower, find, splitup = string.gmatch, string.lower, string.find, string.splitup

local fonts              = fonts
local nodes              = nodes
local attributes         = attributes
local node               = node

local trace_goodies      = false  trackers.register("fonts.goodies", function(v) trace_goodies = v end)
local report_goodies     = logs.reporter("fonts","goodies")

local allocate           = utilities.storage.allocate
local setmetatableindex  = table.setmetatableindex

local implement          = interfaces.implement

local texsp              = tex.sp
local formatters         = string.formatters

local otf                = fonts.handlers.otf
local afm                = fonts.handlers.afm
local tfm                = fonts.handlers.tfm

local registerotffeature = otf.features.register
local registerafmfeature = afm.features.register
local registertfmfeature = tfm.features.register

local fontgoodies        = fonts.goodies or { }
fonts.goodies            = fontgoodies

local typefaces          = fonts.typefaces or allocate()
fonts.typefaces          = typefaces

local data               = fontgoodies.data or allocate()
fontgoodies.data         = data

local list               = fontgoodies.list or { }
fontgoodies.list         = list -- no allocate as we want to see what is there

local addotffeature      = otf.enhancers.addfeature

local findfile           = resolvers.findfile

local glyph_code         = nodes.nodecodes.glyph

local nuts               = nodes.nuts
local tonut              = nuts.tonut
local getfont            = nuts.getfont
local getchar            = nuts.getchar
local getattr            = nuts.getattr
local traverse_id        = nuts.traverse_id

function fontgoodies.report(what,trace,goodies)
    if trace_goodies or trace then
        local whatever = goodies[what]
        if whatever then
            report_goodies("goodie %a found in %a",what,goodies.name)
        end
    end
end

local function loadgoodies(filename) -- maybe a merge is better
    local goodies = data[filename] -- we assume no suffix is given
    if goodies ~= nil then
        -- found or tagged unfound
    elseif type(filename) == "string" then
        local fullname = findfile(file.addsuffix(filename,"lfg")) or "" -- prefered suffix
        if fullname == "" then
            fullname = findfile(file.addsuffix(filename,"lua")) or "" -- fallback suffix
        end
        if fullname == "" then
            report_goodies("goodie file '%s.lfg' is not found",filename)
            data[filename] = false -- signal for not found
        else
            goodies = dofile(fullname) or false
            if not goodies then
                report_goodies("goodie file %a is invalid",fullname)
                return nil
            elseif trace_goodies then
                report_goodies("goodie file %a is loaded",fullname)
            end
            goodies.name = goodies.name or "no name"
            for name, fnc in next, list do
                if trace_goodies then
                    report_goodies("handling goodie %a",name)
                end
                fnc(goodies)
            end
            goodies.initialized = true
            data[filename] = goodies
        end
    end
    return goodies
end

function fontgoodies.register(name,fnc) -- will be a proper sequencer
    list[name] = fnc
end

fontgoodies.load = loadgoodies

-- register goodies file

local function setgoodies(tfmdata,value)
    local goodies = tfmdata.goodies
    if not goodies then -- actually an error
        goodies = { }
        tfmdata.goodies = goodies
    end
    for filename in gmatch(value,"[^, ]+") do
        -- we need to check for duplicates
        local ok = loadgoodies(filename)
        if ok then
            if trace_goodies then
                report_goodies("assigning goodie %a",filename)
            end
            goodies[#goodies+1] = ok
        end
    end
end

-- this will be split into good-* files and this file might become good-ini.lua

-- featuresets

local function flattenedfeatures(t,tt)
    -- first set value dominates
    local tt = tt or { }
    for i=1,#t do
        local ti = t[i]
        if type(ti) == "table" then
            flattenedfeatures(ti,tt)
        elseif tt[ti] == nil then
            tt[ti] = true
        end
    end
    for k, v in next, t do
        if type(k) ~= "number" then -- not tonumber(k)
            if type(v) == "table" then
                flattenedfeatures(v,tt)
            elseif tt[k] == nil then
                tt[k] = v
            end
        end
    end
    return tt
end

-- fonts.features.flattened = flattenedfeatures

local function prepare_features(goodies,name,set)
    if set then
        local ff = flattenedfeatures(set)
        local fullname = goodies.name .. "::" .. name
        local n, s = fonts.specifiers.presetcontext(fullname,"",ff)
        goodies.featuresets[name] = s -- set
        if trace_goodies then
            report_goodies("feature set %a gets number %a and name %a",name,n,fullname)
        end
        return n
    end
end

fontgoodies.prepare_features = prepare_features

local function initialize(goodies,tfmdata)
    local featuresets = goodies.featuresets
    local goodiesname = goodies.name
    if featuresets then
        if trace_goodies then
            report_goodies("checking featuresets in %a",goodies.name)
        end
        for name, set in next, featuresets do
            prepare_features(goodies,name,set)
        end
    end
end

fontgoodies.register("featureset",initialize)

local function setfeatureset(tfmdata,set,features)
    local goodies = tfmdata.goodies -- shared ?
    if goodies then
        local properties = tfmdata.properties
        local what
        for i=1,#goodies do
            -- last one wins
            local g = goodies[i]
            what = g.featuresets and g.featuresets[set] or what
        end
        if what then
            for feature, value in next, what do
                if features[feature] == nil then
                    features[feature] = value
                end
            end
            properties.mode = what.mode or properties.mode
        end
    end
end

-- postprocessors (we could hash processor and share code)

function fontgoodies.registerpostprocessor(tfmdata,f,prepend)
    local postprocessors = tfmdata.postprocessors
    if not postprocessors then
        tfmdata.postprocessors = { f }
    elseif prepend then
        table.insert(postprocessors,f,1)
    else
        table.insert(postprocessors,f)
    end
end

local function setpostprocessor(tfmdata,processor)
    local goodies = tfmdata.goodies
    if goodies and type(processor) == "string" then
        local found = { }
        local asked = utilities.parsers.settings_to_array(processor)
        for i=1,#goodies do
            local g = goodies[i]
            local p = g.postprocessors
            if p then
                for i=1,#asked do
                    local a = asked[i]
                    local f = p[a]
                    if type(f) == "function" then
                        found[a] = f
                    end
                end
            end
        end
        local postprocessors = tfmdata.postprocessors or { }
        for i=1,#asked do
            local a = asked[i]
            local f = found[a]
            if f then
                postprocessors[#postprocessors+1] = f
            end
        end
        if #postprocessors > 0 then
            tfmdata.postprocessors = postprocessors
        end
    end
end

-- colorschemes

local colorschemes       = fontgoodies.colorschemes or allocate { }
fontgoodies.colorschemes = colorschemes
colorschemes.data        = colorschemes.data or { }

local function setcolorscheme(tfmdata,scheme)
    if type(scheme) == "string" then
        local goodies = tfmdata.goodies
        -- todo : check for already defined in shared
        if goodies then
            local what
            for i=1,#goodies do
                -- last one counts
                local g = goodies[i]
                what = g.colorschemes and g.colorschemes[scheme] or what
            end
            if type(what) == "table" then
                -- this is font bound but we can share them if needed
                -- just as we could hash the conversions (per font)
                local hash       = tfmdata.resources.unicodes
                local reverse    = { }
                local characters = tfmdata.characters
                for i=1,#what do
                    local w = what[i]
                    for j=1,#w do
                        local name = w[j]
                        if name == "*" then
                            -- inefficient but only used for tracing anyway
                            for _, unicode in next, hash do
                                reverse[unicode] = i
                            end
                        elseif type(name) == "number" then
                            reverse[name] = i
                        elseif find(name,":",1,true) then
                            local start, stop = splitup(name,":")
                            start = tonumber(start)
                            stop = tonumber(stop)
                            if start and stop then
                                -- limited usage: we only deal with non reassigned
                                -- maybe some day I'll also support the ones with a
                                -- tounicode in this range
                                for unicode=start,stop do
                                    if characters[unicode] then
                                        reverse[unicode] = i
                                    end
                                end
                            end
                        else
                            local unicode = hash[name]
                            if unicode then
                                reverse[unicode] = i
                            end
                        end
                    end
                end
                tfmdata.properties.colorscheme = reverse
                return
            end
        end
    end
    tfmdata.properties.colorscheme = false
end

local fontproperties = fonts.hashes.properties

local a_colorscheme  = attributes.private('colorscheme')
local setnodecolor   = nodes.tracers.colors.set

-- function colorschemes.coloring(head)
--     local lastfont, lastscheme
--     local done = false
--     for n in traverse_id(glyph_code,tonut(head)) do
--         local a = getattr(n,a_colorscheme)
--         if a then
--             local f = getfont(n)
--             if f ~= lastfont then
--                 lastscheme = fontproperties[f].colorscheme
--                 lastfont   = f
--             end
--             if lastscheme then
--                 local sc = lastscheme[getchar(n)]
--                 if sc then
--                     done = true
--                     setnodecolor(n,"colorscheme:"..a..":"..sc) -- slow
--                 end
--             end
--         end
--     end
--     return head, done
-- end

-- seldom used, mostly in manuals, so non critical .. anyhow, somewhat faster:

-- function colorschemes.coloring(head)
--     local lastfont   = nil
--     local lastattr   = nil
--     local lastscheme = nil
--     local lastprefix = nil
--     local done       = nil
--     for n in traverse_id(glyph_code,tonut(head)) do
--         local a = getattr(n,a_colorscheme)
--         if a then
--             if a ~= lastattr then
--                 lastattr   = a
--                 lastprefix = "colorscheme:" .. a .. ":"
--             end
--             local f = getfont(n)
--             if f ~= lastfont then
--                 lastfont   = f
--                 lastscheme = fontproperties[f].colorscheme
--             end
--             if lastscheme then
--                 local sc = lastscheme[getchar(n)]
--                 if sc then
--                     setnodecolor(n,lastprefix .. sc) -- slow
--                     done = true
--                 end
--             end
--         end
--     end
--     return head, done
-- end

-- ok, in case we have hundreds of pages colored:

local cache = { } -- this could be a weak table

setmetatableindex(cache,function(t,a)
    local v = { }
    setmetatableindex(v,function(t,c)
        local v = "colorscheme:" .. a .. ":" .. c
        t[c] = v
        return v
    end)
    t[a]= v
    return v
end)

function colorschemes.coloring(head)
    local lastfont   = nil
    local lastattr   = nil
    local lastcache  = nil
    local lastscheme = nil
    local done       = nil
    for n in traverse_id(glyph_code,tonut(head)) do
        local a = getattr(n,a_colorscheme)
        if a then
            local f = getfont(n)
            if f ~= lastfont then
                lastfont   = f
                lastscheme = fontproperties[f].colorscheme
            end
            if a ~= lastattr then
                lastattr  = a
                lastcache = cache[a]
            end
            if lastscheme then
                local sc = lastscheme[getchar(n)]
                if sc then
                    setnodecolor(n,lastcache[sc]) -- we could inline this one
                    done = true
                end
            end
        end
    end
    return head, done
end

function colorschemes.enable()
    nodes.tasks.appendaction("processors","fonts","fonts.goodies.colorschemes.coloring")
    function colorschemes.enable() end
end

local function setextrafeatures(tfmdata)
    local goodies = tfmdata.goodies
    if goodies then
        for i=1,#goodies do
            local g = goodies[i]
            local f = g.features
            if f then
                for feature, specification in next, f do
                    addotffeature(tfmdata.shared.rawdata,feature,specification)
                    registerotffeature {
                        name        = feature,
                        description = formatters["extra: %s"](feature)
                    }
                end
            end
        end
    end
end

local function setextensions(tfmdata)
    local goodies = tfmdata.goodies
    if goodies then
        for i=1,#goodies do
            local g = goodies[i]
            local e = g.extensions
            if e then
                local goodie = g.name or "unknown"
                for i=1,#e do
                    local name = "extension-" .. i
                 -- report_goodies("adding extension %s from %s",name,goodie)
                    otf.enhancers.addfeature(tfmdata.shared.rawdata,name,e[i])
                end
            end
        end
    end
end

-- installation (collected to keep the overview) -- also for type 1

registerotffeature {
    name         = "goodies",
    description  = "goodies on top of built in features",
    initializers = {
        position = 1,
        base     = setgoodies,
        node     = setgoodies,
    }
}

registerotffeature {
    name        = "extrafeatures",
    description = "extra features",
    default     = true,
    initializers = {
        position = 2,
        base     = setextrafeatures,
        node     = setextrafeatures,
    }
}

registerotffeature {
    name        = "extensions",
    description = "extensions to features",
    default     = true,
    initializers = {
        position = 2,
        base     = setextensions,
        node     = setextensions,
    }
}

registerotffeature {
    name        = "featureset",
    description = "goodie feature set",
    initializers = {
        position = 3,
        base     = setfeatureset,
        node     = setfeatureset,
    }
}

registerotffeature {
    name        = "colorscheme",
    description = "goodie color scheme",
    initializers = {
        base = setcolorscheme,
        node = setcolorscheme,
    }
}

registerotffeature {
    name        = "postprocessor",
    description = "goodie postprocessor",
    initializers = {
        base = setpostprocessor,
        node = setpostprocessor,
    }
}

-- afm

registerafmfeature {
    name         = "goodies",
    description  = "goodies on top of built in features",
    initializers = {
        position = 1,
        base     = setgoodies,
        node     = setgoodies,
    }
}

-- tfm

registertfmfeature {
    name         = "goodies",
    description  = "goodies on top of built in features",
    initializers = {
        position = 1,
        base     = setgoodies,
        node     = setgoodies,
    }
}

-- experiment, we have to load the definitions immediately as they precede
-- the definition so they need to be initialized in the typescript

local function initialize(goodies)
    local mathgoodies = goodies.mathematics
    if mathgoodies then
        local virtuals = mathgoodies.virtuals
        local mapfiles = mathgoodies.mapfiles
        local maplines = mathgoodies.maplines
        if virtuals then
            for name, specification in next, virtuals do
                -- beware, they are all constructed
                mathematics.makefont(name,specification,goodies)
            end
        end
        if mapfiles then
            for i=1,#mapfiles do
                fonts.mappings.loadfile(mapfiles[i]) -- todo: backend function
            end
        end
        if maplines then
            for i=1,#maplines do
                fonts.mappings.loadline(maplines[i]) -- todo: backend function
            end
        end
    end
end

fontgoodies.register("mathematics", initialize)

-- the following takes care of explicit file specifications
--
-- files = {
--     name = "antykwapoltawskiego",
--     list = {
--         ["AntPoltLtCond-Regular.otf"] = {
--          -- name   = "antykwapoltawskiego",
--             style  = "regular",
--             weight = "light",
--             width  = "condensed",
--         },
--     },
-- }

-- math italics (not rteally needed)
--
-- it would be nice to have a \noitalics\font option

local function initialize(tfmdata)
    local goodies = tfmdata.goodies
    if goodies then
        local shared = tfmdata.shared
        for i=1,#goodies do
            local mathgoodies = goodies[i].mathematics
            local mathitalics = mathgoodies and mathgoodies.italics
            if mathitalics then
                local properties = tfmdata.properties
                if properties.setitalics then
                    mathitalics = mathitalics[file.nameonly(properties.name)] or mathitalics
                    if mathitalics then
                        if trace_goodies then
                            report_goodies("loading mathitalics for font %a",properties.name)
                        end
                        local corrections   = mathitalics.corrections
                        local defaultfactor = mathitalics.defaultfactor
                     -- properties.mathitalic_defaultfactor = defaultfactor -- we inherit outer one anyway (name will change)
                        if corrections then
                            fontgoodies.registerpostprocessor(tfmdata, function(tfmdata) -- this is another tfmdata (a copy)
                                -- better make a helper so that we have less code being defined
                                local properties = tfmdata.properties
                                local parameters = tfmdata.parameters
                                local characters = tfmdata.characters
                                properties.mathitalic_defaultfactor = defaultfactor
                                properties.mathitalic_defaultvalue  = defaultfactor * parameters.quad
                                if trace_goodies then
                                    report_goodies("assigning mathitalics for font %a",properties.name)
                                end
                                local quad    = parameters.quad
                                local hfactor = parameters.hfactor
                                for k, v in next, corrections do
                                    local c = characters[k]
                                    if c then
                                        if v > -1 and v < 1 then
                                            c.italic = v * quad
                                        else
                                            c.italic = v * hfactor
                                        end
                                    else
                                        report_goodies("invalid mathitalics entry %U for font %a",k,properties.name)
                                    end
                                end
                            end)
                        end
                        return -- maybe not as these can accumulate
                    end
                end
            end
        end
    end
end

registerotffeature {
    name         = "mathitalics",
    description  = "additional math italic corrections",
 -- default      = true,
    initializers = {
        base = initialize,
        node = initialize,
    }
}

-- fontgoodies.register("mathitalics", initialize)

-- files

local function initialize(goodies)
    local files = goodies.files
    if files then
        fonts.names.register(files)
    end
end

fontgoodies.register("files", initialize)

-- some day we will have a define command and then we can also do some
-- proper tracing
--
-- fonts.typefaces["antykwapoltawskiego-condensed"] = {
--     shortcut     = "rm",
--     shape        = "serif",
--     fontname     = "antykwapoltawskiego",
--     normalweight = "light",
--     boldweight   = "medium",
--     width        = "condensed",
--     size         = "default",
--     features     = "default",
-- }

local function initialize(goodies)
    local typefaces = goodies.typefaces
    if typefaces then
        local ft = fonts.typefaces
        for k, v in next, typefaces do
            ft[k] = v
        end
    end
end

fontgoodies.register("typefaces", initialize)

local compositions = { }

function fontgoodies.getcompositions(tfmdata)
    return compositions[file.nameonly(tfmdata.properties.filename or "")]
end

local function initialize(goodies)
    local gc = goodies.compositions
    if gc then
        for k, v in next, gc do
            compositions[k] = v
        end
    end
end

fontgoodies.register("compositions", initialize)

-- extra treatments (on top of defaults): \loadfontgoodies[mytreatments]

local treatmentdata = fonts.treatments.data

local function initialize(goodies)
    local treatments = goodies.treatments
    if treatments then
        for name, data in next, treatments do
            treatmentdata[name] = data -- always wins
        end
    end
end

fontgoodies.register("treatments", initialize)

local filenames       = fontgoodies.filenames or allocate()
fontgoodies.filenames = filenames

local filedata        = filenames.data or allocate()
filenames.data        = filedata

local function initialize(goodies) -- design sizes are registered global
    local fn = goodies.filenames
    if fn then
        for usedname, alternativenames in next, fn do
            filedata[usedname] = alternativenames
        end
    end
end

fontgoodies.register("filenames", initialize)

function fontgoodies.filenames.resolve(name)
    local fd = filedata[name]
    if fd and findfile(name) == "" then
        for i=1,#fd do
            local fn = fd[i]
            if findfile(fn) ~= "" then
                return fn
            end
        end
    else
        -- no lookup, just use the regular mechanism
    end
    return name
end

local designsizes       = fontgoodies.designsizes or allocate()
fontgoodies.designsizes = designsizes

local designdata        = designsizes.data or allocate()
designsizes.data        = designdata

local function initialize(goodies) -- design sizes are registered global
    local gd = goodies.designsizes
    if gd then
        for name, data in next, gd do
            local ranges = { }
            for size, file in next, data do
                if size ~= "default" then
                    ranges[#ranges+1] =  { texsp(size), file } -- also lower(file)
                end
            end
            table.sort(ranges,function(a,b) return a[1] < b[1] end)
            designdata[lower(name)] = { -- overloads, doesn't merge!
                default = data.default,
                ranges  = ranges,
            }
        end
    end
end

fontgoodies.register("designsizes", initialize)

function fontgoodies.designsizes.register(name,size,specification)
    local d = designdata[name]
    if not d then
        d = {
            ranges  = { },
            default = nil, -- so we have no default set
        }
        designdata[name] = d
    end
    if size == "default" then
        d.default = specification
    else
        if type(size) == "string" then
            size = texsp(size) -- hm
        end
        local ranges = d.ranges
        ranges[#ranges+1] = { size, specification }
    end
end

function fontgoodies.designsizes.filename(name,spec,size) -- returns nil of no match
    local data = designdata[lower(name)]
    if data then
        if not spec or spec == "" or spec == "default" then
            return data.default
        elseif spec == "auto" then
            local ranges = data.ranges
            if ranges then
                for i=1,#ranges do
                    local r = ranges[i]
                    if r[1] >= size then -- todo: rounding so maybe size - 100
                        return r[2]
                    end
                end
            end
            return data.default or (ranges and ranges[#ranges][2])
        end
    end
end

-- The following file (husayni.lfg) is the experimental setup that we used
-- for Idris font. For the moment we don't store this in the cache and quite
-- probably these files sit in one of the paths:
--
-- tex/context/fonts/goodies
-- tex/fonts/goodies/context
-- tex/fonts/data/foundry/collection
--
-- see lfg files in distribution

-- interface

implement {
    name      = "loadfontgoodies",
    actions   = fontgoodies.load,
    arguments = "string",
    overload  = true, -- for now, permits new font loader
}

implement {
    name      = "enablefontcolorschemes",
    onlyonce  = true,
    actions   = colorschemes.enable,
    overload  = true, -- for now, permits new font loader
}

-- weird place ... depends on math

local function finalize(tfmdata,feature,value)
    mathematics.overloaddimensions(tfmdata,tfmdata,value)
end

registerotffeature {
    name         = "mathdimensions",
    description  = "manipulate math dimensions",
 -- default      = true,
    manipulators = {
        base = finalize,
        node = finalize,
    }
}

-- kern hackery:
--
-- yes  : use goodies table
-- auto : assume features to be set (often ccmp only)

local function setkeepligatures(tfmdata,value)
    if not tfmdata.properties.keptligatures then
        local goodies = tfmdata.goodies
        if goodies then
            for i=1,#goodies do
                local g = goodies[i]
                local letterspacing = g.letterspacing
                if letterspacing then
                    local keptligatures = letterspacing.keptligatures
                    if keptligatures then
                        local unicodes = tfmdata.resources.unicodes -- so we accept names
                        local hash = { }
                        for k, v in next, keptligatures do
                            local u = unicodes[k]
                            if u then
                                hash[u] = true
                            else
                                -- error: unknown name
                            end
                        end
                        tfmdata.properties.keptligatures = hash
                    end
                end
            end
        end
    end
end

registerotffeature {
    name         = "keepligatures",
    description  = "keep ligatures in letterspacing",
    initializers = {
        base = setkeepligatures,
        node = setkeepligatures,
    }
}
