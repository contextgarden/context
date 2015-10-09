if not modules then modules = { } end modules ['font-otc'] = {
    version   = 1.001,
    comment   = "companion to font-otf.lua (context)",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local format, insert, sortedkeys = string.format, table.insert, table.sortedkeys
local type, next = type, next
local lpegmatch = lpeg.match
local utfbyte = utf.byte

-- we assume that the other otf stuff is loaded already

local trace_loading       = false  trackers.register("otf.loading", function(v) trace_loading = v end)
local report_otf          = logs.reporter("fonts","otf loading")

local fonts               = fonts
local otf                 = fonts.handlers.otf
local registerotffeature  = otf.features.register
local setmetatableindex   = table.setmetatableindex

local normalized = {
    substitution = "substitution",
    single       = "substitution",
    ligature     = "ligature",
    alternate    = "alternate",
    multiple     = "multiple",
    kern         = "kern",
}

local types = {
    substitution = "gsub_single",
    ligature     = "gsub_ligature",
    alternate    = "gsub_alternate",
    multiple     = "gsub_multiple",
    kern         = "gpos_pair",
}

setmetatableindex(types, function(t,k) t[k] = k return k end) -- "key"

local everywhere = { ["*"] = { ["*"] = true } } -- or: { ["*"] = { "*" } }
local noflags    = { }

-- beware: shared, maybe we should copy the sequence

local function addfeature(data,feature,specifications)
    local descriptions = data.descriptions
    local resources    = data.resources
    local features     = resources.features
    local sequences    = resources.sequences
    if not features or not sequences then
        return
    end
    local gsubfeatures = features.gsub
    if gsubfeatures and gsubfeatures[feature] then
        return -- already present
    end
    local fontfeatures = resources.features or everywhere
    local unicodes     = resources.unicodes
    local splitter     = lpeg.splitter(" ",unicodes)
    local done         = 0
    local skip         = 0
    if not specifications[1] then
        -- so we accept a one entry specification
        specifications = { specifications }
    end

    local function tounicode(code)
        if not code then
            return
        elseif type(code) == "number" then
            return code
        else
            return unicodes[code] or utfbyte(code)
        end
    end

    local coverup      = otf.coverup
    local coveractions = coverup.actions
    local stepkey      = coverup.stepkey
    local register     = coverup.register

    for s=1,#specifications do
        local specification = specifications[s]
        local valid         = specification.valid
        if not valid or valid(data,specification,feature) then
            local initialize = specification.initialize
            if initialize then
                -- when false is returned we initialize only once
                specification.initialize = initialize(specification,data) and initialize or nil
            end
            local askedfeatures = specification.features or everywhere
            local askedsteps    = specifications.steps or specification.subtables or { specification.data } or { }
            local featuretype   = normalized[specification.type or "substitution"] or "substitution"
            local featureflags  = specification.flags or noflags
            local featureorder  = specification.order or { feature }
            local added         = false
            local nofsteps      = 0
            local steps         = { }
            for i=1,#askedsteps do
                local list     = askedsteps[i]
                local coverage = { }
                local cover    = coveractions[featuretype]
                local format   = nil
                if not cover then
                    -- unknown
                elseif featuretype == "substitution" then
                    for code, replacement in next, list do
                        local unicode     = tounicode(code)
                        local description = descriptions[unicode]
                        if description then
                            if type(replacement) == "table" then
                                replacement = replacement[1]
                            end
                            replacement = tounicode(replacement)
                            if replacement and descriptions[replacement] then
                                cover(coverage,unicode,replacement)
                                done = done + 1
                            else
                                skip = skip + 1
                            end
                        else
                            skip = skip + 1
                        end
                    end
                elseif featuretype == "ligature" then
                    for code, ligature in next, list do
                        local unicode     = tounicode(code)
                        local description = descriptions[unicode]
                        if description then
                            if type(ligature) == "string" then
                                ligature = { lpegmatch(splitter,ligature) }
                            end
                            local present = true
                            for i=1,#ligature do
                                local l = ligature[i]
                                local u = tounicode(l)
                                if descriptions[u] then
                                    ligature[i] = u
                                else
                                    present = false
                                    break
                                end
                            end
                            if present then
                                cover(coverage,unicode,ligature)
                                done = done + 1
                            else
                                skip = skip + 1
                            end
                        else
                            skip = skip + 1
                        end
                    end
                elseif featuretype == "alternate" then
                    for code, replacement in next, list do
                        local unicode     = tounicode(code)
                        local description = descriptions[unicode]
                        if not description then
                            skip = skip + 1
                        elseif type(replacement) == "table" then
                            local r = { }
                            for i=1,#replacement do
                                local u = tounicode(replacement[i])
                                r[i] = descriptions[u] and u or unicode
                            end
                            cover(coverage,unicode,r)
                            done = done + 1
                        else
                            local u = tounicode(replacement)
                            if u then
                                cover(coverage,unicode,{ u })
                                done = done + 1
                            else
                                skip = skip + 1
                            end
                        end
                    end
                elseif featuretype == "multiple" then -- todo: unicode can be table
                    for code, replacement in next, list do
                        local unicode     = tounicode(code)
                        local description = descriptions[unicode]
                        if not description then
                            skip = skip + 1
                        elseif type(replacement) == "table" then
                            local r, n = { }, 0
                            for i=1,#replacement do
                                local u = tounicode(replacement[i])
                                if descriptions[u] then
                                    n = n + 1
                                    r[n] = u
                                end
                            end
                            if n > 0 then
                                cover(coverage,unicode,r)
                                done = done + 1
                            else
                                skip = skip + 1
                            end
                        else
                            local u = tounicode(replacement)
                            if u then
                                cover(coverage,unicode,{ u })
                                done = done + 1
                            else
                                skip = skip + 1
                            end
                        end
                    end
                elseif featuretype == "kern" then
                    for code, replacement in next, list do
                        local unicode     = tounicode(code)
                        local description = descriptions[unicode]
                        if description and type(replacement) == "table" then
                            local r = { }
                            for k, v in next, replacement do
                                local u = tounicode(k)
                                if u then
                                    r[u] = v
                                end
                            end
                            if next(r) then
                                cover(coverage,unicode,r)
                                done = done + 1
                            else
                                skip = skip + 1
                            end
                        else
                            skip = skip + 1
                        end
                    end
                    format = "kern"
                end
                if next(coverage) then
                    added = true
                    nofsteps = nofsteps + 1
                    steps[nofsteps] = register(coverage,featuretype,format,feature,nofsteps,descriptions,resources)
                end
            end
            if added then
                -- script = { lang1, lang2, lang3 } or script = { lang1 = true, ... }
                for k, v in next, askedfeatures do
                    if v[1] then
                        askedfeatures[k] = table.tohash(v)
                    end
                end
                local sequence = {
                    chain     = 0,
                    features  = { [feature] = askedfeatures },
                    flags     = featureflags,
                    name      = feature, -- not needed
                    order     = featureorder,
                    [stepkey] = steps,
                    nofsteps  = nofsteps,
                    type      = types[featuretype],
                }
                if specification.prepend then
                    insert(sequences,1,sequence)
                else
                    insert(sequences,sequence)
                end
                -- register in metadata (merge as there can be a few)
                if not gsubfeatures then
                    gsubfeatures  = { }
                    fontfeatures.gsub = gsubfeatures
                end
                local k = gsubfeatures[feature]
                if not k then
                    k = { }
                    gsubfeatures[feature] = k
                end
                for script, languages in next, askedfeatures do
                    local kk = k[script]
                    if not kk then
                        kk = { }
                        k[script] = kk
                    end
                    for language, value in next, languages do
                        kk[language] = value
                    end
                end
            end
        end
    end
    if trace_loading then
        report_otf("registering feature %a, affected glyphs %a, skipped glyphs %a",feature,done,skip)
    end
end

otf.enhancers.addfeature = addfeature

local extrafeatures = { }

function otf.addfeature(name,specification)
    if type(name) == "table" then
        specification = name
        name = specification.name
    end
    if type(name) == "string" then
        extrafeatures[name] = specification
    end
end

local function enhance(data,filename,raw)
    for feature, specification in next, extrafeatures do
        addfeature(data,feature,specification)
    end
end

otf.enhancers.register("check extra features",enhance)

-- tlig --

local tlig = { -- we need numbers for some fonts so ...
 -- endash        = "hyphen hyphen",
 -- emdash        = "hyphen hyphen hyphen",
    [0x2013]      = { 0x002D, 0x002D },
    [0x2014]      = { 0x002D, 0x002D, 0x002D },
 -- quotedblleft  = "quoteleft quoteleft",
 -- quotedblright = "quoteright quoteright",
 -- quotedblleft  = "grave grave",
 -- quotedblright = "quotesingle quotesingle",
 -- quotedblbase  = "comma comma",
}

local tlig_specification = {
    type     = "ligature",
    features = everywhere,
    data     = tlig,
    order    = { "tlig" },
    flags    = noflags,
    prepend  = true,
}

otf.addfeature("tlig",tlig_specification)

registerotffeature {
    name        = 'tlig',
    description = 'tex ligatures',
}

-- trep

local trep = {
 -- [0x0022] = 0x201D,
    [0x0027] = 0x2019,
 -- [0x0060] = 0x2018,
}

local trep_specification = {
    type      = "substitution",
    features  = everywhere,
    data      = trep,
    order     = { "trep" },
    flags     = noflags,
    prepend   = true,
}

otf.addfeature("trep",trep_specification)

registerotffeature {
    name        = 'trep',
    description = 'tex replacements',
}

-- tcom

if characters.combined then

    local tcom = { }

    local function initialize()
        characters.initialize()
        for first, seconds in next, characters.combined do
            for second, combination in next, seconds do
                tcom[combination] = { first, second }
            end
        end
        -- return false
    end

    local tcom_specification = {
        type       = "ligature",
        features   = everywhere,
        data       = tcom,
        order     = { "tcom" },
        flags      = noflags,
        initialize = initialize,
    }

    otf.addfeature("tcom",tcom_specification)

    registerotffeature {
        name        = 'tcom',
        description = 'tex combinations',
    }

end

-- anum

local anum_arabic = {
    [0x0030] = 0x0660,
    [0x0031] = 0x0661,
    [0x0032] = 0x0662,
    [0x0033] = 0x0663,
    [0x0034] = 0x0664,
    [0x0035] = 0x0665,
    [0x0036] = 0x0666,
    [0x0037] = 0x0667,
    [0x0038] = 0x0668,
    [0x0039] = 0x0669,
}

local anum_persian = {
    [0x0030] = 0x06F0,
    [0x0031] = 0x06F1,
    [0x0032] = 0x06F2,
    [0x0033] = 0x06F3,
    [0x0034] = 0x06F4,
    [0x0035] = 0x06F5,
    [0x0036] = 0x06F6,
    [0x0037] = 0x06F7,
    [0x0038] = 0x06F8,
    [0x0039] = 0x06F9,
}

local function valid(data)
    local features = data.resources.features
    if features then
        for k, v in next, features do
            for k, v in next, v do
                if v.arab then
                    return true
                end
            end
        end
    end
end

local anum_specification = {
    {
        type     = "substitution",
        features = { arab = { urd = true, dflt = true } },
        order    = { "anum" },
        data     = anum_arabic,
        flags    = noflags, -- { },
        valid    = valid,
    },
    {
        type     = "substitution",
        features = { arab = { urd = true } },
        order    = { "anum" },
        data     = anum_persian,
        flags    = noflags, -- { },
        valid    = valid,
    },
}

otf.addfeature("anum",anum_specification) -- todo: only when there is already an arab script feature

registerotffeature {
    name        = 'anum',
    description = 'arabic digits',
}

-- maybe:

-- fonts.handlers.otf.addfeature("hangulfix",{
--     type     = "substitution",
--     features = { ["hang"] = { ["*"] = true } },
--     data     = {
--         [0x1160] = 0x119E,
--     },
--     order    = { "hangulfix" },
--     flags    = { },
--     prepend  = true,
-- })

-- fonts.handlers.otf.features.register {
--     name        = 'hangulfix',
--     description = 'fixes for hangul',
-- }

-- fonts.handlers.otf.addfeature {
--     name = "stest",
--     type = "substitution",
--     data = {
--         a = "X",
--         b = "P",
--     }
-- }
-- fonts.handlers.otf.addfeature {
--     name = "atest",
--     type = "alternate",
--     data = {
--         a = { "X", "Y" },
--         b = { "P", "Q" },
--     }
-- }
-- fonts.handlers.otf.addfeature {
--     name = "mtest",
--     type = "multiple",
--     data = {
--         a = { "X", "Y" },
--         b = { "P", "Q" },
--     }
-- }
-- fonts.handlers.otf.addfeature {
--     name = "ltest",
--     type = "ligature",
--     data = {
--         X = { "a", "b" },
--         Y = { "d", "a" },
--     }
-- }
-- fonts.handlers.otf.addfeature {
--     name = "ktest",
--     type = "kern",
--     data = {
--         a = { b = -500 },
--     }
-- }
