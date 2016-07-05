if not modules then modules = { } end modules ['good-ini'] = {
    version   = 1.000,
    comment   = "companion to font-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- depends on ctx

local type, next = type, next
local gmatch = string.gmatch
local sortedhash, insert = table.sortedhash, table.insert

local fonts              = fonts

local trace_goodies      = false  trackers.register("fonts.goodies", function(v) trace_goodies = v end)
local report_goodies     = logs.reporter("fonts","goodies")

local allocate           = utilities.storage.allocate
local implement          = interfaces.implement
local findfile           = resolvers.findfile
local formatters         = string.formatters

local otf                = fonts.handlers.otf
local afm                = fonts.handlers.afm
local tfm                = fonts.handlers.tfm

local registerotffeature = otf.features.register
local registerafmfeature = afm.features.register
local registertfmfeature = tfm.features.register

local addotffeature      = otf.enhancers.addfeature

local fontgoodies        = fonts.goodies or { }
fonts.goodies            = fontgoodies

local data               = fontgoodies.data or { }
fontgoodies.data         = data -- no allocate as we want to see what is there

local list               = fontgoodies.list or { }
fontgoodies.list         = list -- no allocate as we want to see what is there

fontgoodies.suffixes     = { "lfg", "lua" } -- lfg is context specific and should not be used elsewhere

local contextsetups      = fonts.specifiers.contextsetups

function fontgoodies.report(what,trace,goodies)
    if trace_goodies or trace then
        local whatever = goodies[what]
        if whatever then
            report_goodies("goodie %a found in %a",what,goodies.name)
        end
    end
end

local function locate(filename)
    local suffixes = fontgoodies.suffixes
    for i=1,#suffixes do
        local suffix = suffixes[i]
        local fullname = findfile(file.addsuffix(filename,suffix))
        if fullname and fullname ~= "" then
            return fullname
        end
    end
end

local function loadgoodies(filename) -- maybe a merge is better
    local goodies = data[filename] -- we assume no suffix is given
    if goodies ~= nil then
        -- found or tagged unfound
    elseif type(filename) == "string" then
        local fullname = locate(filename)
        if not fullname or fullname == "" then
            report_goodies("goodie file %a is not found (suffixes: % t)",filename,fontgoodies.suffixes)
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
            for i=1,#list do
                local g = list[i]
                if trace_goodies then
                    report_goodies("handling goodie %a",g[1])
                end
                g[2](goodies)
            end
            goodies.initialized = true
            data[filename] = goodies
        end
    end
    return goodies
end

function fontgoodies.register(name,fnc,prepend) -- will be a proper sequencer
    for i=1,#list do
        local g = list[i]
        if g[1] == name then
            g[2] = fnc --overload
            return
        end
    end
    local g = { name, fnc }
    if prepend then
        insert(list,g,prepend == true and 1 or prepend)
    else
        insert(list,g)
    end
end

fontgoodies.load = loadgoodies

if implement then

    implement {
        name      = "loadfontgoodies",
        actions   = loadgoodies,
        arguments = "string",
        overload  = true, -- for now, permits new font loader
    }

end

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

-- featuresets

local function flattenedfeatures(t,tt)
    -- first set value dominates
    local tt = tt or { }
    for i=1,#t do
        local ti = t[i]
        local ty = type(ti)
        if ty == "table" then
            flattenedfeatures(ti,tt)
        elseif ty == "string" then
            local set = contextsetups[ti]
            if set then
                for k, v in next, set do
                    if k ~= "number" then
                        tt[k] = v or nil
                    end
                end
            else
                -- bad
            end
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

local function initialize(goodies)
    local featuresets = goodies.featuresets
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
        insert(postprocessors,f,prepend == true and 1 or prepend)
    else
        insert(postprocessors,f)
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

local function setextrafeatures(tfmdata)
    local goodies = tfmdata.goodies
    if goodies then
        for i=1,#goodies do
            local g = goodies[i]
            local f = g.features
            if f then
                local rawdata = tfmdata.shared.rawdata
                local done    = { }
                -- indexed
                for i=1,#f do
                    local specification = f[i]
                    local feature = specification.name
                    if feature then
                        addotffeature(rawdata,feature,specification)
                        registerotffeature {
                            name        = feature,
                            description = formatters["extra: %s"](feature)
                        }
                    end
                    done[i] = true
                end
                -- hashed
                for feature, specification in sortedhash(f) do
                    if not done[feature] then
                        feature = specification.name or feature
                        specification.name = feature
                        addotffeature(rawdata,feature,specification)
                        registerotffeature {
                            name        = feature,
                            description = formatters["extra: %s"](feature)
                        }
                    end
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

-- installation

local goodies_specification = {
    name         = "goodies",
    description  = "goodies on top of built in features",
    initializers = {
        position = 1,
        base     = setgoodies,
        node     = setgoodies,
    }
}

registerotffeature(goodies_specification)
registerafmfeature(goodies_specification)
registertfmfeature(goodies_specification)

-- maybe more of the following could be for type one too

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
    name        = "postprocessor",
    description = "goodie postprocessor",
    initializers = {
        base = setpostprocessor,
        node = setpostprocessor,
    }
}
