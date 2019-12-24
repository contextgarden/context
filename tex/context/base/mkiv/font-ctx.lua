if not modules then modules = { } end modules ['font-ctx'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- At some point I will clean up the code here so that at the tex end
-- the table interface is used.
--
-- Todo: make a proper 'next id' mechanism (register etc) or wait till 'true'
-- in virtual fonts indices is implemented.

local tostring, next, type, rawget, tonumber = tostring, next, type, rawget, tonumber

local format, gmatch, match, find, lower, upper, gsub, byte, topattern = string.format, string.gmatch, string.match, string.find, string.lower, string.upper, string.gsub, string.byte, string.topattern
local concat, serialize, sort, fastcopy, mergedtable = table.concat, table.serialize, table.sort, table.fastcopy, table.merged
local sortedhash, sortedkeys, sequenced = table.sortedhash, table.sortedkeys, table.sequenced
local parsers = utilities.parsers
local settings_to_hash, hash_to_string, settings_to_array = parsers.settings_to_hash, parsers.hash_to_string, parsers.settings_to_array
local formatcolumns = utilities.formatters.formatcolumns
local mergehashes = utilities.parsers.mergehashes
local formatters = string.formatters
local basename = file.basename

local utfchar, utfbyte = utf.char, utf.byte
local round = math.round

local context, commands = context, commands

local P, S, C, Cc, Cf, Cg, Ct, lpegmatch = lpeg.P, lpeg.S, lpeg.C, lpeg.Cc, lpeg.Cf, lpeg.Cg, lpeg.Ct, lpeg.match

local trace_features      = false  trackers.register("fonts.features",   function(v) trace_features   = v end)
local trace_defining      = false  trackers.register("fonts.defining",   function(v) trace_defining   = v end)
local trace_designsize    = false  trackers.register("fonts.designsize", function(v) trace_designsize = v end)
local trace_usage         = false  trackers.register("fonts.usage",      function(v) trace_usage      = v end)
local trace_mapfiles      = false  trackers.register("fonts.mapfiles",   function(v) trace_mapfiles   = v end)
local trace_automode      = false  trackers.register("fonts.automode",   function(v) trace_automode   = v end)
local trace_merge         = false  trackers.register("fonts.merge",      function(v) trace_merge      = v end)

local report              = logs.reporter("fonts")
local report_features     = logs.reporter("fonts","features")
local report_cummulative  = logs.reporter("fonts","cummulative")
local report_defining     = logs.reporter("fonts","defining")
local report_status       = logs.reporter("fonts","status")
local report_mapfiles     = logs.reporter("fonts","mapfiles")

local setmetatableindex   = table.setmetatableindex

local implement           = interfaces.implement

local chardata            = characters.data

local fonts               = fonts
local handlers            = fonts.handlers
local otf                 = handlers.otf -- brrr
local afm                 = handlers.afm -- brrr
local tfm                 = handlers.tfm -- brrr
local names               = fonts.names
local definers            = fonts.definers
local specifiers          = fonts.specifiers
local constructors        = fonts.constructors
local loggers             = fonts.loggers
local fontgoodies         = fonts.goodies
local helpers             = fonts.helpers
local hashes              = fonts.hashes
local currentfont         = font.current
local definefont          = font.define

local getprivateslot      = helpers.getprivateslot

local cleanname           = names.cleanname

local encodings           = fonts.encodings
----- aglunicodes         = encodings.agl.unicodes
local aglunicodes         = nil -- delayed loading

local nuts                = nodes.nuts
local tonut               = nuts.tonut

local nextchar            = nuts.traversers.char

local getattr             = nuts.getattr
local setattr             = nuts.setattr
local getprop             = nuts.getprop
local setprop             = nuts.setprop
local setsubtype          = nuts.setsubtype

local texgetdimen         = tex.getdimen
local texsetcount         = tex.setcount
local texget              = tex.get

local texdefinefont       = tex.definefont
local texsp               = tex.sp

local fontdata            = hashes.identifiers
local characters          = hashes.characters
local descriptions        = hashes.descriptions
local properties          = hashes.properties
local resources           = hashes.resources
local unicodes            = hashes.unicodes
local csnames             = hashes.csnames
local lastmathids         = hashes.lastmathids
local exheights           = hashes.exheights
local emwidths            = hashes.emwidths
local parameters          = hashes.parameters

local designsizefilename  = fontgoodies.designsizes.filename

local ctx_char            = context.char
local ctx_getvalue        = context.getvalue

local otffeatures         = otf.features
local otftables           = otf.tables

local registerotffeature  = otffeatures.register

local sequencers          = utilities.sequencers
local appendgroup         = sequencers.appendgroup
local appendaction        = sequencers.appendaction

specifiers.contextsetups  = specifiers.contextsetups  or { }
specifiers.contextnumbers = specifiers.contextnumbers or { }
specifiers.contextmerged  = specifiers.contextmerged  or { }
specifiers.synonyms       = specifiers.synonyms       or { }

local setups   = specifiers.contextsetups
local numbers  = specifiers.contextnumbers
local merged   = specifiers.contextmerged
local synonyms = specifiers.synonyms

storage.register("fonts/setups" ,  setups ,  "fonts.specifiers.contextsetups" )
storage.register("fonts/numbers",  numbers,  "fonts.specifiers.contextnumbers")
storage.register("fonts/merged",   merged,   "fonts.specifiers.contextmerged")
storage.register("fonts/synonyms", synonyms, "fonts.specifiers.synonyms")

-- inspect(setups)

if environment.initex then
    setmetatableindex(setups,function(t,k)
        return type(k) == "number" and rawget(t,numbers[k]) or nil
    end)
else
    setmetatableindex(setups,function(t,k)
        local v = type(k) == "number" and rawget(t,numbers[k])
        if v then
            t[k] = v
            return v
        end
    end)
end

-- this will move elsewhere ...

local function getfontname(tfmdata)
    return basename(type(tfmdata) == "number" and properties[tfmdata].name or tfmdata.properties.name)
end

helpers.name = getfontname

local addformatter = utilities.strings.formatters.add

addformatter(formatters,"font:name",    [["'"..fontname(%s).."'"]],          { fontname  = helpers.name })
addformatter(formatters,"font:features",[["'"..sequenced(%s," ",true).."'"]],{ sequenced = table.sequenced })

-- ... like font-sfm or so

constructors.resolvevirtualtoo = true -- context specific (due to resolver)

if CONTEXTLMTXMODE and CONTEXTLMTXMODE > 0 then
    constructors.fixprotrusion = false
end

constructors.sharefonts        = true -- experimental
constructors.nofsharedhashes   = 0
constructors.nofsharedvectors  = 0
constructors.noffontsloaded    = 0
constructors.autocleanup       = true

-- we can get rid of the tfm instance when we have fast access to the
-- scaled character dimensions at the tex end, e.g. a fontobject.width
-- actually we already have some of that now as virtual keys in glyphs
--
-- flushing the kern and ligature tables from memory saves a lot (only
-- base mode) but it complicates vf building where the new characters
-- demand this data .. solution: functions that access them

-- font.getcopy = font.getfont -- we always want the table that context uses

function constructors.cleanuptable(tfmdata)
    if constructors.autocleanup and tfmdata.properties.virtualized then
        for k, v in next, tfmdata.characters do
            if v.commands then v.commands = nil end
        --  if v.kerns    then v.kerns    = nil end
        end
    end
end

do

    local shares = { }
    local hashes = { }

    local nofinstances = 0
    local instances    = setmetatableindex(function(t,k)
        nofinstances = nofinstances + 1
        t[k] = nofinstances
        return nofinstances
    end)

    function constructors.trytosharefont(target,tfmdata)
        constructors.noffontsloaded = constructors.noffontsloaded + 1
        if constructors.sharefonts then
            local fonthash = target.specification.hash
            if fonthash then
                local properties = target.properties
                local fullname   = target.fullname
                local fontname   = target.fontname
                local psname     = target.psname
                -- for the moment here:
                local instance = properties.instance
                if instance then
                    local format = tfmdata.properties.format
                    if format == "opentype" then
                        target.streamprovider = 1
                    elseif format == "truetype" then
                        target.streamprovider = 2
                    else
                        target.streamprovider = 0
                    end
                    if target.streamprovider > 0 then
                        if fullname then
                            fullname = fullname .. ":" .. instances[instance]
                            target.fullname = fullname
                        end
                        if fontname then
                            fontname = fontname .. ":" .. instances[instance]
                            target.fontname = fontname
                        end
                        if psname then
                            -- this one is used for the funny prefix in font names in pdf
                            -- so it has ot be kind of unique in order to avoid subset prefix
                            -- clashes being reported
                            psname = psname   .. ":" .. instances[instance]
                            target.psname = psname
                        end
                    end
                end
                --
                local sharedname = hashes[fonthash]
                if sharedname then
                    -- this is ok for context as we know that only features can mess with font definitions
                    -- so a similar hash means that the fonts are similar too
                    if trace_defining then
                        report_defining("font %a uses backend resources of font %a (%s)",target.fullname,sharedname,"common hash")
                    end
                    target.fullname = sharedname
                    properties.sharedwith = sharedname
                    constructors.nofsharedfonts = constructors.nofsharedfonts + 1
                    constructors.nofsharedhashes = constructors.nofsharedhashes + 1
                else
                    -- the one takes more time (in the worst case of many cjk fonts) but it also saves
                    -- embedding time .. haha, this is interesting: when i got a clash on subset tag
                    -- collision i saw in the source that these tags are also using a hash like below
                    -- so maybe we should have an option to pass it from lua
                    local characters = target.characters
                    local n = 1
                    local t = { target.psname }
                    -- for the moment here:
                    if instance then
                        n = n + 1
                        t[n] = instance
                    end
                    --
                    local u = sortedkeys(characters)
                    for i=1,#u do
                        local k = u[i]
                        n = n + 1 ; t[n] = k
                        n = n + 1 ; t[n] = characters[k].index or k
                    end
                    local checksum   = md5.HEX(concat(t," "))
                    local sharedname = shares[checksum]
                    local fullname   = target.fullname
                    if sharedname then
                        if trace_defining then
                            report_defining("font %a uses backend resources of font %a (%s)",fullname,sharedname,"common vector")
                        end
                        fullname = sharedname
                        properties.sharedwith= sharedname
                        constructors.nofsharedfonts = constructors.nofsharedfonts + 1
                        constructors.nofsharedvectors = constructors.nofsharedvectors + 1
                    else
                        shares[checksum] = fullname
                    end
                    target.fullname  = fullname
                    hashes[fonthash] = fullname
                end
            end
        end
    end

end

directives.register("fonts.checksharing",function(v)
    if not v then
        report_defining("font sharing in backend is disabled")
    end
    constructors.sharefonts = v
end)

function definers.resetnullfont()
    -- resetting is needed because tikz misuses nullfont
    local parameters = fonts.nulldata.parameters
    --
    parameters.slant         = 0 -- 1
    parameters.space         = 0 -- 2
    parameters.space_stretch = 0 -- 3
    parameters.space_shrink  = 0 -- 4
    parameters.x_height      = 0 -- 5
    parameters.quad          = 0 -- 6
    parameters.extra_space   = 0 -- 7
    --
    constructors.enhanceparameters(parameters) -- official copies for us
    --
    definers.resetnullfont = function() end
end

implement {
    name     = "resetnullfont",
    onlyonce = true,
    actions  = function()
        for i=1,7 do
            -- we have no direct method yet
            context([[\fontdimen%s\nullfont\zeropoint]],i)
        end
        definers.resetnullfont()
    end
}

-- this cannot be a feature initializer as there is no auto namespace
-- so we never enter the loop then; we can store the defaults in the tma
-- file (features.gpos.mkmk = 1 etc)

local needsnodemode = { -- we will have node mode by default anyway
 -- gsub_single              = true,
    gsub_multiple            = true,
 -- gsub_alternate           = true,
 -- gsub_ligature            = true,
    gsub_context             = true,
    gsub_contextchain        = true,
    gsub_reversecontextchain = true,
 -- chainsub                 = true,
 -- reversesub               = true,
    gpos_mark2base           = true,
    gpos_mark2ligature       = true,
    gpos_mark2mark           = true,
    gpos_cursive             = true,
 -- gpos_single              = true,
 -- gpos_pair                = true,
    gpos_context             = true,
    gpos_contextchain        = true,
}

otftables.scripts.auto = "automatic fallback to latn when no dflt present"

-- setmetatableindex(otffeatures.descriptions,otftables.features)

local function checkedscript(tfmdata,resources,features)
    local latn   = false
    local script = false
    if resources.features then
        for g, list in next, resources.features do
            for f, scripts in next, list do
                if scripts.dflt then
                    script = "dflt"
                    break
                elseif scripts.latn then
                    latn = true
                end
            end
        end
    end
    if not script then
        script = latn and "latn" or "dflt"
    end
    if trace_automode then
        report_defining("auto script mode, using script %a in font %!font:name!",script,tfmdata)
    end
    features.script = script
    return script
end

-- basemode combined with dynamics is somewhat tricky

local function checkedmode(tfmdata,resources,features)
    local sequences = resources.sequences
    if sequences and #sequences > 0 then
        local script    = features.script   or "dflt"
        local language  = features.language or "dflt"
        for feature, value in next, features do
            if value then
                local found = false
                for i=1,#sequences do
                    local sequence = sequences[i]
                    local features = sequence.features
                    if features then
                        local scripts = features[feature]
                        if scripts then
                            local languages = scripts[script]
                            if languages and languages[language] then
                                if found then
                                    -- more than one lookup
                                    if trace_automode then
                                        report_defining("forcing mode %a, font %!font:name!, feature %a, script %a, language %a, %s",
                                            "node",tfmdata,feature,script,language,"multiple lookups")
                                    end
                                    features.mode = "node"
                                    return "node"
                                elseif needsnodemode[sequence.type] then
                                    if trace_automode then
                                        report_defining("forcing mode %a, font %!font:name!, feature %a, script %a, language %a, %s",
                                            "node",tfmdata,feature,script,language,"no base support")
                                    end
                                    features.mode = "node"
                                    return "node"
                                else
                                    -- at least one lookup
                                    found = true
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    if trace_automode then
        report_defining("forcing mode base, font %!font:name!",tfmdata)
    end
    features.mode = "base" -- new, or is this wrong?
    return "base"
end

definers.checkedscript = checkedscript
definers.checkedmode   = checkedmode

local function modechecker(tfmdata,features,mode) -- we cannot adapt features as they are shared!
    if trace_features then
        report_features("fontname %!font:name!, features %!font:features!",tfmdata,features)
    end
    local rawdata   = tfmdata.shared.rawdata
    local resources = rawdata and rawdata.resources
    local script    = features.script
    if resources then
        if script == "auto" then
            script = checkedscript(tfmdata,resources,features)
        end
        if mode == "auto" then
            mode = checkedmode(tfmdata,resources,features)
        end
    else
        report_features("missing resources for font %!font:name!",tfmdata)
    end
    return mode
end

registerotffeature {
    -- we only set the checker and leave other settings of the mode
    -- feature as they are
    name        = "mode",
    modechecker = modechecker,
}

-- -- default = true anyway
--
-- local normalinitializer = constructors.getfeatureaction("otf","initializers","node","analyze")
--
-- local function analyzeinitializer(tfmdata,value,features) -- attr
--     if value == "auto" and features then
--         value = features.init or features.medi or features.fina or features.isol or false
--     end
--     return normalinitializer(tfmdata,value,features)
-- end
--
-- registerotffeature {
--     name         = "analyze",
--     initializers = {
--         node = analyzeinitializer,
--     },
-- }

do

    local beforecopyingcharacters = sequencers.new {
        name      = "beforecopyingcharacters",
        arguments = "target,original",
    }

    appendgroup(beforecopyingcharacters,"before") -- user
    appendgroup(beforecopyingcharacters,"system") -- private
    appendgroup(beforecopyingcharacters,"after" ) -- user

    function constructors.beforecopyingcharacters(original,target)
        local runner = beforecopyingcharacters.runner
        if runner then
            runner(original,target)
        end
    end

    local aftercopyingcharacters = sequencers.new {
        name      = "aftercopyingcharacters",
        arguments = "target,original",
    }

    appendgroup(aftercopyingcharacters,"before") -- user
    appendgroup(aftercopyingcharacters,"system") -- private
    appendgroup(aftercopyingcharacters,"after" ) -- user

    function constructors.aftercopyingcharacters(original,target)
        local runner = aftercopyingcharacters.runner
        if runner then
            runner(original,target)
        end
    end

end

--[[ldx--
<p>So far we haven't really dealt with features (or whatever we want
to pass along with the font definition. We distinguish the following
situations:</p>
situations:</p>

<code>
name:xetex like specs
name@virtual font spec
name*context specification
</code>
--ldx]]--

-- currently fonts are scaled while constructing the font, so we
-- have to do scaling of commands in the vf at that point using e.g.
-- "local scale = g.parameters.factor or 1" after all, we need to
-- work with copies anyway and scaling needs to be done at some point;
-- however, when virtual tricks are used as feature (makes more
-- sense) we scale the commands in fonts.constructors.scale (and set the
-- factor there)

local loadfont = definers.loadfont

function definers.loadfont(specification,size,id) -- overloads the one in font-def
    local variants = definers.methods.variants
    local virtualfeatures = specification.features.virtual
    if virtualfeatures and virtualfeatures.preset then
        local variant = variants[virtualfeatures.preset]
        if variant then
            return variant(specification,size,id)
        end
    else
        local tfmdata = loadfont(specification,size,id)
     -- constructors.checkvirtualid(tfmdata,id)
        return tfmdata
    end
end

local function predefined(specification)
    local variants = definers.methods.variants
    local detail = specification.detail
    if detail ~= "" and variants[detail] then
        specification.features.virtual = { preset = detail }
    end
    return specification
end

definers.registersplit("@", predefined,"virtual")

local normalize_features = otffeatures.normalize     -- should be general

local function definecontext(name,t) -- can be shared
    local number = setups[name] and setups[name].number or 0 -- hm, numbers[name]
    if number == 0 then
        number = #numbers + 1
        numbers[number] = name
    end
    t.number = number
    setups[name] = t
    return number, t
end

-- {a,b,c} as table (so we don' need to parse again when it gets applied)
-- we will update this ... when we have foo={a,b,c} then we can keep the table

-- \definefontfeature[demo][a={b,c}]
-- \definefontfeature[demo][a={b=12,c={34,35}}]

local h = setmetatableindex(function(t,k)
    local v = "," .. k .. ","
    t[k] = v
    return v
end)

-- local function removefromhash(hash,key)
--     local pattern = h[key]
--     for k in next, hash do
--         if k ~= key and find(h[k],pattern) then -- if find(k,",") and ...
--             hash[k] = nil
--         end
--     end
-- end

local function presetcontext(name,parent,features) -- will go to con and shared
    if features == "" and find(parent,"=",1,true) then
        features = parent
        parent = ""
    end
    if not features or features == "" then
        features = { }
    elseif type(features) == "string" then
        features = normalize_features(settings_to_hash(features))
     -- if type(value) == "string" and find(value,"[=:]") then
     --     local t = settings_to_hash_colon_too(value) -- clashes with foo=file:bar
        for key, value in next, features do
            if type(value) == "string" and find(value,"[=]") then
                local t = settings_to_hash(value)
                if next(t) then
                    features[key] = sequenced(normalize_features(t,true),",")
                end
            end
        end
    else
        features = normalize_features(features)
    end
    -- todo: synonyms, and not otf bound
    if parent ~= "" then
        for p in gmatch(parent,"[^, ]+") do
            local s = setups[p]
            if s then
                for k, v in next, s do
                    -- no, as then we cannot overload: e.g. math,mathextra
                    -- reverted, so we only take from parent when not set
                    if features[k] == nil then
                        features[k] = v
                    end
                end
            else
                -- just ignore an undefined one .. i.e. we can refer to not yet defined
            end
        end
    end
    -- these are auto set so in order to prevent redundant definitions
    -- we need to preset them (we hash the features and adding a default
    -- setting during initialization may result in a different hash)
    --
    -- for k,v in next, triggers do
    --     if features[v] == nil then -- not false !
    --         local vv = default_features[v]
    --         if vv then features[v] = vv end
    --     end
    -- end
    --
    for feature,value in next, features do
        if value == nil then -- not false !
            local default = default_features[feature]
            if default ~= nil then
                features[feature] = default
            end
        end
    end
    -- sparse 'm so that we get a better hash and less test (experimental
    -- optimization)
    local t = { } -- can we avoid t ?
    for k,v in next, features do
     -- if v then t[k] = v end
        t[k] = v
    end
    -- the number is needed for dynamic features; maybe number should always be
    -- renewed as we can redefine features ... i need a test
    local number = setups[name] and setups[name].number or 0
    if number == 0 then
        number = #numbers + 1
        numbers[number] = name
    end
    --
    t.number = number
    -- there is the special case of combined features as we have in math but maybe
    -- this has to change some day ... otherwise we mess up dynamics (ok, we could
    -- impose a limit there: no combined features)
    --
    -- done elsewhere (!)
    --
 -- removefromhash(setups,name) -- can have changed (like foo,extramath)
    --
    setups[name] = t
    return number, t
end

local function adaptcontext(pattern,features)
    local pattern = topattern(pattern,false,true)
    for name in next, setups do
        if find(name,pattern) then
            presetcontext(name,name,features)
        end
    end
end

-- local function contextnumber(name) -- will be replaced
--     local t = setups[name]
--     if not t then
--         return 0
--     elseif t.auto then -- check where used, autolanguage / autoscript?
--         local lng = tonumber(tex.language)
--         local tag = name .. ":" .. lng
--         local s = setups[tag]
--         if s then
--             return s.number or 0
--         else
--             local script, language = languages.association(lng)
--             if t.script ~= script or t.language ~= language then
--                 local s = fastcopy(t)
--                 local n = #numbers + 1
--                 setups[tag] = s
--                 numbers[n] = tag
--                 s.number = n
--                 s.script = script
--                 s.language = language
--                 return n
--             else
--                 setups[tag] = t
--                 return t.number or 0
--             end
--         end
--     else
--         return t.number or 0
--     end
-- end

local function contextnumber(name) -- will be replaced
    local t = setups[name]
    return t and t.number or 0
end

local function mergecontext(currentnumber,extraname,option) -- number string number (used in scrp-ini
    local extra = setups[extraname]
    if extra then
        local current = setups[numbers[currentnumber]]
        local mergedfeatures = { }
        local mergedname = nil
        if option < 0 then
            if current then
                for k, v in next, current do
                    if not extra[k] then
                        mergedfeatures[k] = v
                    end
                end
            end
            mergedname = currentnumber .. "-" .. extraname
        else
            if current then
                for k, v in next, current do
                    mergedfeatures[k] = v
                end
            end
            for k, v in next, extra do
                mergedfeatures[k] = v
            end
            mergedname = currentnumber .. "+" .. extraname
        end
        local number = #numbers + 1
        mergedfeatures.number = number
        numbers[number] = mergedname
        merged[number] = option
        setups[mergedname] = mergedfeatures
        return number -- contextnumber(mergedname)
    else
        return currentnumber
    end
end

local extrasets = { }

setmetatableindex(extrasets,function(t,k)
    local v = mergehashes(setups,k)
    t[k] = v
    return v
end)

local function mergecontextfeatures(currentname,extraname,how,mergedname) -- string string
    local extra = setups[extraname] or extrasets[extraname]
    if extra then
        local current = setups[currentname]
        local mergedfeatures = { }
        if how == "+" then
            if current then
                for k, v in next, current do
                    mergedfeatures[k] = v
                end
            end
            for k, v in next, extra do
                mergedfeatures[k] = v
            end
            if trace_merge then
                report_features("merge %a, method %a, current %|T, extra %|T, result %|T",mergedname,"add",current or { },extra,mergedfeatures)
            end
        elseif how == "-" then
            if current then
                for k, v in next, current do
                    mergedfeatures[k] = v
                end
            end
            for k, v in next, extra do
                -- only boolean features
                if v == true then
                    mergedfeatures[k] = false
                end
            end
            if trace_merge then
                report_features("merge %a, method %a, current %|T, extra %|T, result %|T",mergedname,"subtract",current or { },extra,mergedfeatures)
            end
        else -- =
            for k, v in next, extra do
                mergedfeatures[k] = v
            end
            if trace_merge then
                report_features("merge %a, method %a, result %|T",mergedname,"replace",mergedfeatures)
            end
        end
        local number = #numbers + 1
        mergedfeatures.number = number
        numbers[number] = mergedname
        merged[number] = option
        setups[mergedname] = mergedfeatures
        return number
    else
        return numbers[currentname] or 0
    end
end

local function registercontext(fontnumber,extraname,option)
    local extra = setups[extraname]
    if extra then
        local mergedfeatures = { }
        local mergedname     = nil
        if option < 0 then
            mergedname = fontnumber .. "-" .. extraname
        else
            mergedname = fontnumber .. "+" .. extraname
        end
        for k, v in next, extra do
            mergedfeatures[k] = v
        end
        local number = #numbers + 1
        mergedfeatures.number = number
        numbers[number] = mergedname
        merged[number] = option
        setups[mergedname] = mergedfeatures
        return number -- contextnumber(mergedname)
    else
        return 0
    end
end

local function registercontextfeature(mergedname,extraname,how)
    local extra = setups[extraname]
    if extra then
        local mergedfeatures = { }
        for k, v in next, extra do
            mergedfeatures[k] = v
        end
        local number = #numbers + 1 -- we somehow end up with steps of 2
        mergedfeatures.number = number
        numbers[number] = mergedname
        merged[number] = how == "=" and 1 or 2 -- 1=replace, 2=combine
        setups[mergedname] = mergedfeatures
        return number -- contextnumber(mergedname)
    else
        report_features("unknown feature %a cannot be merged into %a using method %a",extraname,mergedname,how)
        return 0
    end
end

specifiers.presetcontext   = presetcontext
specifiers.contextnumber   = contextnumber
specifiers.mergecontext    = mergecontext
specifiers.registercontext = registercontext
specifiers.definecontext   = definecontext

-- we extend the hasher:

-- constructors.hashmethods.virtual = function(list)
--     local s = { }
--     local n = 0
--     for k, v in next, list do
--         n = n + 1
--         s[n] = k -- no checking on k
--     end
--     if n > 0 then
--         sort(s)
--         for i=1,n do
--             local k = s[i]
--             s[i] = k .. '=' .. tostring(list[k])
--         end
--         return concat(s,"+")
--     end
-- end

constructors.hashmethods.virtual = function(list)
    local s = { }
    local n = 0
    for k, v in next, list do
        n = n + 1
     -- if v == true then
     --     s[n] = k .. '=true'
     -- elseif v == false then
     --     s[n] = k .. '=false'
     -- else
     --     s[n] = k .. "=" .. v
     -- end
        s[n] = k .. "=" .. tostring(v)
    end
    if n > 0 then
        sort(s)
        return concat(s,"+")
    end
end

-- end of redefine

-- local withcache = { } -- concat might be less efficient than nested tables
--
-- local function withset(name,what)
--     local zero = texgetattribute(0)
--     local hash = zero .. "+" .. name .. "*" .. what
--     local done = withcache[hash]
--     if not done then
--         done = mergecontext(zero,name,what)
--         withcache[hash] = done
--     end
--     texsetattribute(0,done)
-- end
--
-- local function withfnt(name,what,font)
--     local font = font or currentfont()
--     local hash = font .. "*" .. name .. "*" .. what
--     local done = withcache[hash]
--     if not done then
--         done = registercontext(font,name,what)
--         withcache[hash] = done
--     end
--     texsetattribute(0,done)
-- end

function specifiers.showcontext(name)
    return setups[name] or setups[numbers[name]] or setups[numbers[tonumber(name)]] or { }
end

-- we need a copy as we will add (fontclass) goodies to the features and
-- that is bad for a shared table

-- local function splitcontext(features) -- presetcontext creates dummy here
--     return fastcopy(setups[features] or (presetcontext(features,"","") and setups[features]))
-- end

-- local function splitcontext(features) -- presetcontext creates dummy here
--     local sf = setups[features]
--     if not sf then
--         local n -- number
--         if find(features,",") then
--             -- let's assume a combination which is not yet defined but just specified (as in math)
--             n, sf = presetcontext(features,features,"")
--         else
--             -- we've run into an unknown feature and or a direct spec so we create a dummy
--             n, sf = presetcontext(features,"","")
--         end
--     end
--     return fastcopy(sf)
-- end

local function splitcontext(features) -- presetcontext creates dummy here
    local n, sf
    if find(features,",") then
        --
        -- from elsewhere (!)
        --
        -- this will become:
        --
     -- if find(features,"^reset," then
            setups[features] = nil
     -- end
        -- let's assume a combination which is not yet defined but just specified (as in math)
        n, sf = presetcontext(features,features,"")
    else
        sf = setups[features]
        if not sf then
            -- we've run into an unknown feature and or a direct spec so we create a dummy
            n, sf = presetcontext(features,"","")
        end
    end
    return fastcopy(sf)
end

-- local splitter = lpeg.splitat("=")
--
-- local function splitcontext(features)
--     local setup = setups[features]
--     if setup then
--         return setup
--     elseif find(features,",",1,true) then
--         -- This is not that efficient but handy anyway for quick and dirty tests
--         -- beware, due to the way of caching setups you can get the wrong results
--         -- when components change. A safeguard is to nil the cache.
--         local merge = nil
--         for feature in gmatch(features,"[^, ]+") do
--             if find(feature,"=",1,true) then
--                 local k, v = lpegmatch(splitter,feature)
--                 if k and v then
--                     if not merge then
--                         merge = { k = v }
--                     else
--                         merge[k] = v
--                     end
--                 end
--             else
--                 local s = setups[feature]
--                 if not s then
--                     -- skip
--                 elseif not merge then
--                     merge = s
--                 else
--                     for k, v in next, s do
--                         merge[k] = v
--                     end
--                 end
--             end
--         end
--         setup = merge and presetcontext(features,"",merge) and setups[features]
--         -- actually we have to nil setups[features] in order to permit redefinitions
--         setups[features] = nil
--     end
--     return setup or (presetcontext(features,"","") and setups[features]) -- creates dummy
-- end

specifiers.splitcontext = splitcontext

function specifiers.contexttostring(name,kind,separator,yes,no,strict,omit) -- not used
    return hash_to_string(
        mergedtable(handlers[kind].features.defaults or {},setups[name] or {}),
        separator, yes, no, strict, omit or { "number" }
    )
end

local function starred(features) -- no longer fallbacks here
    local detail = features.detail
    if detail and detail ~= "" then
        features.features.normal = splitcontext(detail)
    else
        features.features.normal = { }
    end
    return features
end

definers.registersplit('*',starred,"featureset")

-- sort of xetex mode, but without [] and / as we have file: and name: etc

local space      = P(" ")
local spaces     = space^0
local separator  = S(";,")
local equal      = P("=")
local sometext   = C((1-equal-space-separator)^1)
local truevalue  = P("+") * spaces * sometext                           * Cc(true)
local falsevalue = P("-") * spaces * sometext                           * Cc(false)
local somevalue  =                   sometext * spaces                  * Cc(true)
local keyvalue   =                   sometext * spaces * equal * spaces * sometext
local pattern    = Cf(Ct("") * (space + separator + Cg(falsevalue + truevalue + keyvalue + somevalue))^0, rawset)

local function colonized(specification)
    specification.features.normal = normalize_features(lpegmatch(pattern,specification.detail))
    return specification
end

definers.registersplit(":",colonized,"direct")

-- define (two steps)

local sizepattern, splitpattern, specialscale  do

    ----- space          = P(" ")
    ----- spaces         = space^0
    local leftparent     = (P"(")
    local rightparent    = (P")")
    local leftbrace      = (P"{")
    local rightbrace     = (P"}")
    local withinparents  = leftparent * (1-rightparent)^0 * rightparent
    local withinbraces   = leftbrace  * (1-rightbrace )^0 * rightbrace
    local value          = C((withinparents + withinbraces + (1-space))^1)
    local dimension      = C((space/"" + P(1))^1)
    local rest           = C(P(1)^0)
    local scale_none     =                     Cc(0)
    local scale_at       = (P("at") +P("@")) * Cc(1) * spaces * dimension -- dimension
    local scale_sa       = P("sa")           * Cc(2) * spaces * dimension -- number
    local scale_mo       = P("mo")           * Cc(3) * spaces * dimension -- number
    local scale_scaled   = P("scaled")       * Cc(4) * spaces * dimension -- number
    local scale_ht       = P("ht")           * Cc(5) * spaces * dimension -- dimension
    local scale_cp       = P("cp")           * Cc(6) * spaces * dimension -- dimension

    specialscale = { [5] = "ht", [6] = "cp" }

    sizepattern  = spaces * (scale_at + scale_sa + scale_mo + scale_ht + scale_cp + scale_scaled + scale_none)
    splitpattern = spaces * value * spaces * rest

end

function helpers.splitfontpattern(str)
    local name, size = lpegmatch(splitpattern,str)
    local kind, size = lpegmatch(sizepattern,size)
    return name, kind, size
end

function helpers.fontpatternhassize(str)
    local name, size = lpegmatch(splitpattern,str)
    local kind, size = lpegmatch(sizepattern,size)
    return size or false
end

local specification -- still needed as local ?

local getspecification = definers.getspecification

-- we can make helper macros which saves parsing (but normaly not
-- that many calls, e.g. in mk a couple of 100 and in metafun 3500)

local specifiers = { }

do  -- else too many locals

    ----- ctx_setdefaultfontname = context.fntsetdefname
    ----- ctx_setsomefontname    = context.fntsetsomename
    ----- ctx_setemptyfontsize   = context.fntsetnopsize
    ----- ctx_setsomefontsize    = context.fntsetsomesize
    ----- ctx_letvaluerelax      = context.letvaluerelax

    local starttiming            = statistics.starttiming
    local stoptiming             = statistics.stoptiming

    local scanners               = tokens.scanners
    local scanstring             = scanners.string
    local scaninteger            = scanners.integer
    local scannumber             = scanners.number
    local scanboolean            = scanners.boolean

    local setmacro               = tokens.setters.macro
    local scanners               = interfaces.scanners

 -- function commands.definefont_one(str)

    scanners.definefont_one = function()
        local str = scanstring()

        starttiming(fonts)
        if trace_defining then
            report_defining("memory usage before: %s",statistics.memused())
            report_defining("start stage one: %s",str)
        end
        local fullname, size = lpegmatch(splitpattern,str)
        local lookup, name, sub, method, detail = getspecification(fullname)
        if not name then
            report_defining("strange definition %a",str)
         -- ctx_setdefaultfontname()
        elseif name == "unknown" then
         -- ctx_setdefaultfontname()
        else
         -- ctx_setsomefontname(name)
            setmacro("somefontname",name,"global")
        end
        -- we can also use a count for the size
        if size and size ~= "" then
            local mode, size = lpegmatch(sizepattern,size)
            if size and mode then
                texsetcount("scaledfontmode",mode)
             -- ctx_setsomefontsize(size)
                setmacro("somefontsize",size)
            else
                texsetcount("scaledfontmode",0)
             -- ctx_setemptyfontsize()
            end
        elseif true then
            -- so we don't need to check in tex
            texsetcount("scaledfontmode",2)
         -- ctx_setemptyfontsize()
        else
            texsetcount("scaledfontmode",0)
         -- ctx_setemptyfontsize()
        end
        specification = definers.makespecification(str,lookup,name,sub,method,detail,size)
        if trace_defining then
            report_defining("stop stage one")
        end
    end

    local function nice_cs(cs)
        return (gsub(cs,".->", ""))
    end

    local n               = 0
    local busy            = false
    local combinefeatures = false

    directives.register("fonts.features.combine",function(v)
        combinefeatures = v
    end)

    scanners.definefont_two = function()
        local global          = scanboolean() -- \ifx\fontclass\empty\s!false\else\s!true\fi
        local cs              = scanstring () -- {#csname}%
        local str             = scanstring () -- \somefontfile
        local size            = scaninteger() -- \d_font_scaled_font_size
        local inheritancemode = scaninteger() -- \c_font_feature_inheritance_mode
        local classfeatures   = scanstring () -- \m_font_class_features
        local fontfeatures    = scanstring () -- \m_font_features
        local classfallbacks  = scanstring () -- \m_font_class_fallbacks
        local fontfallbacks   = scanstring () -- \m_font_fallbacks
        local mathsize        = scaninteger() -- \fontface
        local textsize        = scaninteger() -- \d_font_scaled_text_face
        local relativeid      = scaninteger() -- \relativefontid
        local classgoodies    = scanstring () -- \m_font_class_goodies
        local goodies         = scanstring () -- \m_font_goodies
        local classdesignsize = scanstring () -- \m_font_class_designsize
        local fontdesignsize  = scanstring () -- \m_font_designsize
        local scaledfontmode  = scaninteger() -- \scaledfontmode

        if trace_defining then
            report_defining("start stage two: %s, size %s, features %a & %a, mode %a",str,size,classfeatures,fontfeatures,inheritancemode)
        end
        -- name is now resolved and size is scaled cf sa/mo
        local lookup, name, sub, method, detail = getspecification(str or "")
        -- new (todo: inheritancemode)
        local designsize = fontdesignsize ~= "" and fontdesignsize or classdesignsize or ""
        local designname = designsizefilename(name,designsize,size)
        if designname and designname ~= "" then
            if trace_defining or trace_designsize then
                report_defining("remapping name %a, specification %a, size %a, designsize %a",name,designsize,size,designname)
            end
            -- we don't catch detail here
            local o_lookup, o_name, o_sub, o_method, o_detail = getspecification(designname)
            if o_lookup and o_lookup ~= "" then lookup = o_lookup end
            if o_method and o_method ~= "" then method = o_method end
            if o_detail and o_detail ~= "" then detail = o_detail end
            name = o_name
            sub = o_sub
        end
        -- so far
        -- some settings can have been overloaded
        if lookup and lookup ~= "" then
            specification.lookup = lookup
        end
        if relativeid and relativeid ~= "" then -- experimental hook
            local id = tonumber(relativeid) or 0
            specification.relativeid = id > 0 and id
        end
        --
        specification.name      = name
        specification.size      = size
        specification.sub       = (sub and sub ~= "" and sub) or specification.sub
        specification.mathsize  = mathsize
        specification.textsize  = textsize
        specification.goodies   = goodies
        specification.cs        = cs
        specification.global    = global
        specification.scalemode = scaledfontmode -- context specific
        if detail and detail ~= "" then
            specification.method = method or "*"
            specification.detail = detail
        elseif specification.detail and specification.detail ~= "" then
            -- already set
        elseif inheritancemode == 0 then
            -- nothing
        elseif inheritancemode == 1 then
            -- fontonly
            if fontfeatures and fontfeatures ~= "" then
                specification.method = "*"
                specification.detail = fontfeatures
            end
            if fontfallbacks and fontfallbacks ~= "" then
                specification.fallbacks = fontfallbacks
            end
        elseif inheritancemode == 2 then
            -- classonly
            if classfeatures and classfeatures ~= "" then
                specification.method = "*"
                specification.detail = classfeatures
            end
            if classfallbacks and classfallbacks ~= "" then
                specification.fallbacks = classfallbacks
            end
        elseif inheritancemode == 3 then
            -- fontfirst
            if combinefeatures then
                if classfeatures and classfeatures ~= "" then
                    specification.method = "*"
                    if fontfeatures and fontfeatures ~= "" and fontfeatures ~= classfeatures then
                        specification.detail = classfeatures .. "," .. fontfeatures
                    else
                        specification.detail = classfeatures
                    end
                elseif fontfeatures and fontfeatures ~= "" then
                    specification.method = "*"
                    specification.detail = fontfeatures
                end
            else
                if fontfeatures and fontfeatures ~= "" then
                    specification.method = "*"
                    specification.detail = fontfeatures
                elseif classfeatures and classfeatures ~= "" then
                    specification.method = "*"
                    specification.detail = classfeatures
                end
            end
            if fontfallbacks and fontfallbacks ~= "" then
                specification.fallbacks = fontfallbacks
            elseif classfallbacks and classfallbacks ~= "" then
                specification.fallbacks = classfallbacks
            end
        elseif inheritancemode == 4 then
            -- classfirst
            if combinefeatures then
                if fontfeatures and fontfeatures ~= "" then
                    specification.method = "*"
                    if classfeatures and classfeatures ~= "" and classfeatures ~= fontfeatures then
                        specification.detail = fontfeatures .. "," .. classfeatures
                    else
                        specification.detail = fontfeatures
                    end
                elseif classfeatures and classfeatures ~= "" then
                    specification.method = "*"
                    specification.detail = classfeatures
                end
            else
                if classfeatures and classfeatures ~= "" then
                    specification.method = "*"
                    specification.detail = classfeatures
                elseif fontfeatures and fontfeatures ~= "" then
                    specification.method = "*"
                    specification.detail = fontfeatures
                end
            end
            if classfallbacks and classfallbacks ~= "" then
                specification.fallbacks = classfallbacks
            elseif fontfallbacks and fontfallbacks ~= "" then
                specification.fallbacks = fontfallbacks
            end
        end
        --
        local tfmdata = definers.read(specification,size) -- id not yet known (size in spec?)
        --
        local lastfontid = 0
        local tfmtype    = type(tfmdata)
        if tfmtype == "table" then
            -- setting the extra characters will move elsewhere
            local characters = tfmdata.characters
            local parameters = tfmdata.parameters
            local properties = tfmdata.properties
            -- we use char0 as signal; cf the spec pdf can handle this (no char in slot)
            characters[0] = nil
         -- characters[0x00A0] = { width = parameters.space }
         -- characters[0x2007] = { width = characters[0x0030] and characters[0x0030].width or parameters.space } -- figure
         -- characters[0x2008] = { width = characters[0x002E] and characters[0x002E].width or parameters.space } -- period
            --
            local fallbacks = specification.fallbacks or ""
            local mathsize  = (mathsize == 1 or mathsize == 2 or mathsize == 3) and mathsize or nil -- can be unset so we test 1 2 3
            if fallbacks ~= "" and mathsize and not busy then
                busy = true
                -- We need this ugly hack in order to resolve fontnames (at the \TEX end). Originally
                -- math was done in Lua after loading (plugged into aftercopying).
                --
                -- After tl 2017 I'll also do text fallbacks this way (although backups there are done
                -- in a completely different way.)
                if trace_defining then
                    report_defining("defining %a, id %a, target %a, features %a / %a, fallbacks %a / %a, step %a",
                        name,id,nice_cs(cs),classfeatures,fontfeatures,classfallbacks,fontfallbacks,1)
                end
                mathematics.resolvefallbacks(tfmdata,specification,fallbacks)
                context(function()
                    busy = false
                    mathematics.finishfallbacks(tfmdata,specification,fallbacks)
                    local id = definefont(tfmdata)
                    csnames[id] = specification.cs
                    properties.id = id
                    definers.register(tfmdata,id) -- to be sure, normally already done
                    texdefinefont(global,cs,id)
                    constructors.cleanuptable(tfmdata)
                    constructors.finalize(tfmdata)
                    if trace_defining then
                        report_defining("defining %a, id %a, target %a, features %a / %a, fallbacks %a / %a, step %a",
                            name,id,nice_cs(cs),classfeatures,fontfeatures,classfallbacks,fontfallbacks,2)
                    end
                    -- resolved (when designsize is used):
                    local size = round(tfmdata.parameters.size or 655360)
                    setmacro("somefontsize",size.."sp")
                 -- ctx_setsomefontsize(size .. "sp")
                    texsetcount("scaledfontsize",size)
                    lastfontid = id
                    --
                    if trace_defining then
                        report_defining("memory usage after: %s",statistics.memused())
                        report_defining("stop stage two")
                    end
                    --
                    texsetcount("global","lastfontid",lastfontid)
                    specifiers[lastfontid] = { str, size }
                    if not mathsize then
                        -- forget about it (can't happen here)
                    elseif mathsize == 0 then
                        -- can't happen (here)
                    else
                        -- maybe only 1 2 3 (we already test for this)
                        lastmathids[mathsize] = lastfontid
                    end
                    stoptiming(fonts)
                end)
                return
            else
                local id = definefont(tfmdata)
                csnames[id] = specification.cs
                properties.id = id
                definers.register(tfmdata,id) -- to be sure, normally already done
                texdefinefont(global,cs,id)
                constructors.cleanuptable(tfmdata)
                constructors.finalize(tfmdata)
                if trace_defining then
                    report_defining("defining %a, id %a, target %a, features %a / %a, fallbacks %a / %a, step %a",
                        name,id,nice_cs(cs),classfeatures,fontfeatures,classfallbacks,fontfallbacks,"-")
                end
                -- resolved (when designsize is used):
                local size = round(tfmdata.parameters.size or 655360)
                setmacro("somefontsize",size.."sp")
             -- ctx_setsomefontsize(size .. "sp")
                texsetcount("scaledfontsize",size)
                lastfontid = id
            end
        elseif tfmtype == "number" then
            if trace_defining then
                report_defining("reusing %s, id %a, target %a, features %a / %a, fallbacks %a / %a, goodies %a / %a, designsize %a / %a",
                    name,tfmdata,nice_cs(cs),classfeatures,fontfeatures,classfallbacks,fontfallbacks,classgoodies,goodies,classdesignsize,fontdesignsize)
            end
            csnames[tfmdata] = specification.cs
            texdefinefont(global,cs,tfmdata)
            -- resolved (when designsize is used):
            local size = round(fontdata[tfmdata].parameters.size or 0)
         -- ctx_setsomefontsize(size .. "sp")
            setmacro("somefontsize",size.."sp")
            texsetcount("scaledfontsize",size)
            lastfontid = tfmdata
        else
            report_defining("unable to define %a as %a",name,nice_cs(cs))
            lastfontid = -1
            texsetcount("scaledfontsize",0)
         -- ctx_letvaluerelax(cs) -- otherwise the current definition takes the previous one
        end
        if trace_defining then
            report_defining("memory usage after: %s",statistics.memused())
            report_defining("stop stage two")
        end
        --
        texsetcount("global","lastfontid",lastfontid)
        specifiers[lastfontid] = { str, size }
        if not mathsize then
            -- forget about it
        elseif mathsize == 0 then
            -- can't happen (here)
        else
            -- maybe only 1 2 3
            lastmathids[mathsize] = lastfontid
        end
        --
        stoptiming(fonts)
    end

    function scanners.specifiedfontspec()
        local f = specifiers[scaninteger()]
        if f then
            context(f[1])
        end
    end
    function scanners.specifiedfontsize()
        local f = specifiers[scaninteger()]
        if f then
            context(f[2])
        end
    end
    function scanners.specifiedfont()
        local f = specifiers[scaninteger()]
        local s = scannumber()
        if f and s then
            context("%s at %0.2p",f[1],s * f[2]) -- we round to 2 decimals (as at the tex end)
        end
    end

    --

    local function define(specification)
        --
        local name = specification.name
        if not name or name == "" then
            return -1
        else
            starttiming(fonts)
            --
            -- following calls expect a few properties to be set:
            --
            local lookup, name, sub, method, detail = getspecification(name or "")
            --
            specification.name          = (name ~= "" and name) or specification.name
            --
            specification.lookup        = specification.lookup or (lookup ~= "" and lookup) or "file"
            specification.size          = specification.size                                or 655260
            specification.sub           = specification.sub    or (sub    ~= "" and sub)    or ""
            specification.method        = specification.method or (method ~= "" and method) or "*"
            specification.detail        = specification.detail or (detail ~= "" and detail) or ""
            --
            if type(specification.size) == "string" then
                specification.size = texsp(specification.size) or 655260
            end
            --
            specification.specification = "" -- not used
            specification.resolved      = ""
            specification.forced        = ""
            specification.features      = { } -- via detail, maybe some day
            --
            -- we don't care about mathsize textsize goodies fallbacks
            --
            local cs = specification.cs
            if cs == "" then
                cs = nil
                specification.cs = nil
                specification.global = false
            elseif specification.global == nil then
                specification.global = false
            end
            --
            local tfmdata = definers.read(specification,specification.size)
            if not tfmdata then
                return -1, nil
            elseif type(tfmdata) == "number" then
                if cs then
                    texdefinefont(specification.global,cs,tfmdata)
                    csnames[tfmdata] = cs
                end
                stoptiming(fonts)
                return tfmdata, fontdata[tfmdata]
            else
                local id = definefont(tfmdata)
                tfmdata.properties.id = id
                definers.register(tfmdata,id)
                if cs then
                    texdefinefont(specification.global,cs,id)
                    csnames[id] = cs
                end
                constructors.cleanuptable(tfmdata)
                constructors.finalize(tfmdata)
                stoptiming(fonts)
                return id, tfmdata
            end
        end
    end

    definers.define = define

    -- local id, cs = fonts.definers.internal { }
    -- local id, cs = fonts.definers.internal { number = 2 }
    -- local id, cs = fonts.definers.internal { name = "dejavusans" }

    local n = 0

    function definers.internal(specification,cs)
        specification = specification or { }
        local name    = specification.name
        local size    = tonumber(specification.size)
        local number  = tonumber(specification.number)
        local id      = nil
        if not size then
            size = texgetdimen("bodyfontsize")
        end
        if number then
            id = number
        elseif name and name ~= "" then
            local cs = cs or specification.cs
            if not cs then
                n  = n + 1 -- beware ... there can be many and they are often used once
             -- cs = formatters["internal font %s"](n)
                cs = "internal font " .. n
            else
                specification.cs = cs
            end
            id = define {
                name = name,
                size = size,
                cs   = cs,
            }
        end
        if not id then
            id = currentfont()
        end
        return id, csnames[id]
    end

    local read

    if CONTEXTLMTXMODE and CONTEXTLMTXMODE > 0 then -- maybe always
        read = function(name,size)
            return (define { name = name, size = size } or 0)
        end
    else
        read = definers.read
    end

    callbacks.register('define_font', read, "definition of fonts (tfmdata preparation)")

    -- here

    local infofont = 0

    function fonts.infofont()
        if infofont == 0 then
            infofont = define { name = "dejavusansmono", size = texsp("6pt") }
        end
        return infofont
    end

    -- abstract interfacing

    implement { name = "tf", actions = function() setmacro("fontalternative","tf") end }
    implement { name = "bf", actions = function() setmacro("fontalternative","bf") end }
    implement { name = "it", actions = function() setmacro("fontalternative","it") end }
    implement { name = "sl", actions = function() setmacro("fontalternative","sl") end }
    implement { name = "bi", actions = function() setmacro("fontalternative","bi") end }
    implement { name = "bs", actions = function() setmacro("fontalternative","bs") end }

end

local enable_auto_r_scale = false

experiments.register("fonts.autorscale", function(v)
    enable_auto_r_scale = v
end)

-- Not ok, we can best use a database for this. The problem is that we
-- have delayed definitions and so we never know what style is taken
-- as start.

local calculatescale  = constructors.calculatescale

function constructors.calculatescale(tfmdata,scaledpoints,relativeid,specification)
    if specification then
        local scalemode = specification.scalemode
        local special   = scalemode and specialscale[scalemode]
        if special then
            -- we also have available specification.textsize
            local parameters = tfmdata.parameters
         -- local designsize = parameters.designsize
            if     special == "ht" then
                local height = parameters.ascender / parameters.units
                scaledpoints = scaledpoints / height
            elseif special == "cp" then
                local glyph  = tfmdata.descriptions[utfbyte("X")]
                local height = (glyph and glyph.height or parameters.ascender) / parameters.units
                scaledpoints = scaledpoints / height
            end
        end
    end
    local scaledpoints, delta = calculatescale(tfmdata,scaledpoints)
 -- if enable_auto_r_scale and relativeid then -- for the moment this is rather context specific (we need to hash rscale then)
 --     local relativedata = fontdata[relativeid]
 --     local rfmdata = relativedata and relativedata.unscaled and relativedata.unscaled -- just use metadata instead
 --     local id_x_height = rfmdata and rfmdata.parameters and rfmdata.parameters.x_height
 --     local tf_x_height = tfmdata and tfmdata.parameters and tfmdata.parameters.x_height
 --     if id_x_height and tf_x_height then
 --         local rscale = id_x_height/tf_x_height
 --         delta = rscale * delta
 --         scaledpoints = rscale * scaledpoints
 --     end
 -- end
    return round(scaledpoints), round(delta)
end

local designsizes = constructors.designsizes

-- called quite often when in mp labels
-- otf.normalizedaxis

function constructors.hashinstance(specification,force)
    local hash      = specification.hash
    local size      = specification.size
    local fallbacks = specification.fallbacks
    if force or not hash then
        hash = constructors.hashfeatures(specification)
        specification.hash = hash
    end
    if size < 1000 and designsizes[hash] then
        size = round(constructors.scaled(size,designsizes[hash]))
    else
        size = round(size)
    end
    specification.size = size
    if fallbacks then
        return hash .. ' @ ' .. size .. ' @ ' .. fallbacks
    else
        local scalemode = specification.scalemode
        local special   = scalemode and specialscale[scalemode]
        if special then
            return hash .. ' @ ' .. size .. ' @ ' .. special
        else
            return hash .. ' @ ' .. size
        end
    end
end

-- We overload the (generic) resolver:

local resolvers    = definers.resolvers
local hashfeatures = constructors.hashfeatures

function definers.resolve(specification) -- overload function in font-con.lua
    if not specification.resolved or specification.resolved == "" then -- resolved itself not per se in mapping hash
        local r = resolvers[specification.lookup]
        if r then
            r(specification)
        end
    end
    if specification.forced == "" then
        specification.forced = nil
    else
        specification.forced = specification.forced
    end
    -- goodies are a context specific thing and are not always defined
    -- as feature, so we need to make sure we add them here before
    -- hashing because otherwise we get funny goodies applied
    local goodies = specification.goodies
    if goodies and goodies ~= "" then
        -- this adapts the features table so it has best be a copy
        local normal = specification.features.normal
        if not normal then
            specification.features.normal = { goodies = goodies }
        elseif not normal.goodies then
            local g = normal.goodies
            if g and g ~= "" then
                normal.goodies = formatters["%s,%s"](g,goodies)
            else
                normal.goodies = goodies
            end
        end
    end
    -- so far for goodie hacks
    local hash = hashfeatures(specification)
    local name = specification.name or "badfont"
    local sub  = specification.sub
    if sub and sub ~= "" then
        specification.hash = lower(name .. " @ " .. sub .. ' @ ' .. hash)
    else
        specification.hash = lower(name .. " @ "        .. ' @ ' .. hash)
    end
    --
    return specification
end

-- soon to be obsolete:

local mappings = fonts.mappings

local loaded = { -- prevent loading (happens in cont-sys files)
 -- ["original-base.map"     ] = true,
 -- ["original-ams-base.map" ] = true,
 -- ["original-ams-euler.map"] = true,
 -- ["original-public-lm.map"] = true,
}

function mappings.loadfile(name)
    name = file.addsuffix(name,"map")
    if not loaded[name] then
        if trace_mapfiles then
            report_mapfiles("loading map file %a",name)
        end
        lpdf.setmapfile(name)
        loaded[name] = true
    end
end

local loaded = { -- prevent double loading
}

function mappings.loadline(how,line)
    if line then
        how = how .. " " .. line
    elseif how == "" then
        how = "= " .. line
    end
    if not loaded[how] then
        if trace_mapfiles then
            report_mapfiles("processing map line %a",line)
        end
        lpdf.setmapline(how)
        loaded[how] = true
    end
end

function mappings.reset()
    lpdf.setmapfile("") -- tricky ... backend related
end

implement {
    name      = "loadmapfile",
    actions   = mappings.loadfile,
    arguments = "string"
}

implement {
    name      = "loadmapline",
    actions   = mappings.loadline,
    arguments = "string"
}

implement {
    name      = "resetmapfiles",
    actions   = mappings.reset,
    arguments = "string"
}

-- we need an 'do after the banner hook'

-- => commands

local pattern = P("P")
              * (lpeg.patterns.hexdigit^4 / function(s) return tonumber(s,16) end)
              * P(-1)

local function nametoslot(name) -- also supports PXXXXX (4+ positions)
    local t = type(name)
    if t == "string" then
        local unic = unicodes[true]
        local slot = unic[name]
        if slot then
            return slot
        end
        --
        local slot = unic[gsub(name,"_"," ")] or unic[gsub(name,"_","-")] or
                     unic[gsub(name,"-"," ")] or unic[gsub(name,"-","_")] or
                     unic[gsub(name," ","_")] or unic[gsub(name," ","-")]
        if slot then
            return slot
        end
        --
        if not aglunicodes then
            aglunicodes = encodings.agl.unicodes
        end
        local char = characters[true]
        local slot = aglunicodes[name]
        if slot and char[slot] then
            return slot
        end
        local slot = lpegmatch(pattern,name)
        if slot and char[slot] then
            return slot
        end
        -- not in font
    elseif t == "number" then
        if characters[true][name] then
            return slot
        else
            -- not in font
        end
    end
end

local found = { }

local function descriptiontoslot(name)
    local t = type(name)
    if t == "string" then
        -- slow
        local list = sortedkeys(chardata) -- can be a cache with weak tables
        local slot = found[name]
        local char = characters[true]
        if slot then
            return char[slot] and slot or nil
        end
        local NAME = upper(name)
        for i=1,#list do
            slot = list[i]
            local c = chardata[slot]
            local d = c.description
            if d == NAME then
                found[name] = slot
                return char[slot] and slot or nil
            end
        end
        for i=1,#list do
            slot = list[i]
            local c = chardata[slot]
            local s = c.synonyms
            if s then
                for i=1,#s do
                    local si = s[i]
                    if si == name then
                        found[name] = si
                        return char[slot] and slot or nil
                    end
                end
            end
        end
        for i=1,#list do
            slot = list[i]
            local c = chardata[slot]
            local d = c.description
            if d and find(d,NAME) then
                found[name] = slot
                return char[slot] and slot or nil
            end
        end
        for i=1,#list do
            slot = list[i]
            local c = chardata[slot]
            local s = c.synonyms
            if s then
                for i=1,#s do
                    local si = s[i]
                    if find(s[i],name) then
                        found[name] = si
                        return char[slot] and slot or nil
                    end
                end
            end
        end
        -- not in font
    elseif t == "number" then
        if characters[true][name] then
            return slot
        else
            -- not in font
        end
    end
end

local function indextoslot(font,index)
    if not index then
        index = font
        font  = true
    end
    local r = resources[font]
    if r then
        local indices = r.indices
        if not indices then
            indices = { }
            local c = characters[font]
            for unicode, data in next, c do
                local di = data.index
                if di then
                    indices[di] = unicode
                end
            end
            r.indices = indices
        end
        return indices[tonumber(index)]
    end
end

do -- else too many locals

    local entities = characters.entities
    local lowered  = { } -- delayed initialization

    setmetatableindex(lowered,function(t,k)
        for k, v in next, entities do
            local l = lower(k)
            if not entities[l] then
                lowered[l] = v
            end
        end
        setmetatableindex(lowered,nil)
        return lowered[k]
    end)

    local methods = {
        -- entity
        e = function(name)
                return entities[name] or lowered[name] or name
            end,
        -- hexadecimal unicode
        x = function(name)
                local n = tonumber(name,16)
                return n and utfchar(n) or name
            end,
        -- decimal unicode
        d = function(name)
                local n = tonumber(name)
                return n and utfchar(n) or name
            end,
        -- hexadecimal index (slot)
        s = function(name)
                local n = tonumber(name,16)
                local n = n and indextoslot(n)
                return n and utfchar(n) or name
            end,
        -- decimal index
        i = function(name)
                local n = tonumber(name)
                local n = n and indextoslot(n)
                return n and utfchar(n) or name
            end,
        -- name
        n = function(name)
                local n = nametoslot(name)
                return n and utfchar(n) or name
            end,
        -- unicode description (synonym)
        u = function(name)
                local n = descriptiontoslot(name,false)
                return n and utfchar(n) or name
            end,
        -- all
        a = function(name)
                local n = nametoslot(name) or descriptiontoslot(name)
                return n and utfchar(n) or name
            end,
        -- char
        c = function(name)
                return name
            end,
    }

    -- -- nicer:
    --
    -- setmetatableindex(methods,function(t,k) return methods.c end)
    --
    -- local splitter = (C(1) * P(":") + Cc("c")) * C(P(1)^1) / function(method,name)
    --     return methods[method](name)
    -- end
    --
    -- -- more efficient:

    local splitter = C(1) * P(":") * C(P(1)^1) / function(method,name)
        local action = methods[method]
        return action and action(name) or name
    end

    local function tochar(str)
        local t = type(str)
        if t == "number" then
            return utfchar(str)
        elseif t == "string" then
            return lpegmatch(splitter,str) or str
        else
            return str
        end
    end

    helpers.nametoslot        = nametoslot
    helpers.descriptiontoslot = descriptiontoslot
    helpers.indextoslot       = indextoslot
    helpers.tochar            = tochar

    -- interfaces:

    implement {
        name      = "fontchar",
        actions   = { nametoslot, ctx_char },
        arguments = "string",
    }

    implement {
        name      = "fontcharbyindex",
        actions   = { indextoslot, ctx_char },
        arguments = "integer",
    }

    implement {
        name      = "tochar",
        actions   = { tochar, context },
        arguments = "string",
    }

end

-- this will change ...

function loggers.reportdefinedfonts()
    if trace_usage then
        local t, tn = { }, 0
        for id, data in sortedhash(fontdata) do
            local properties = data.properties or { }
            local parameters = data.parameters or { }
            tn = tn + 1
            t[tn] = {
  formatters["%03i"](id                    or 0),
  formatters["%p"  ](parameters.size       or 0),
                     properties.type       or "real",
                     properties.format     or "unknown",
                     properties.name       or "",
                     properties.psname     or "",
                     properties.fullname   or "",
                     properties.sharedwith or "",
            }
        end
        formatcolumns(t,"  ")
        --
        logs.startfilelogging(report,"defined fonts")
        for k=1,tn do
            report(t[k])
        end
        logs.stopfilelogging()
    end
end

logs.registerfinalactions(loggers.reportdefinedfonts)

function loggers.reportusedfeatures()
    -- numbers, setups, merged
    if trace_usage then
        local t, n = { }, #numbers
        for i=1,n do
            local name = numbers[i]
            local setup = setups[name]
            local n = setup.number
            setup.number = nil -- we have no reason to show this
            t[i] = { i, name, sequenced(setup,false,true) } -- simple mode
            setup.number = n -- restore it (normally not needed as we're done anyway)
        end
        formatcolumns(t,"  ")
        logs.startfilelogging(report,"defined featuresets")
        for k=1,n do
            report(t[k])
        end
        logs.stopfilelogging()
    end
end

logs.registerfinalactions(loggers.reportusedfeatures)

-- maybe move this to font-log.lua:

statistics.register("font engine", function()
    local elapsed   = statistics.elapsedseconds(fonts)
    local nofshared = constructors.nofsharedfonts or 0
    local nofloaded = constructors.noffontsloaded or 0
    if nofshared > 0 then
        return format("otf %0.3f, afm %0.3f, tfm %0.3f, %s instances, %s shared in backend, %s common vectors, %s common hashes, load time %s",
            otf.version,afm.version,tfm.version,nofloaded,
            nofshared,constructors.nofsharedvectors,constructors.nofsharedhashes,
            elapsed)
    elseif nofloaded > 0 and elapsed then
        return format("otf %0.3f, afm %0.3f, tfm %0.3f, %s instances, load time %s",
            otf.version,afm.version,tfm.version,nofloaded,
            elapsed)
    else
        return format("otf %0.3f, afm %0.3f, tfm %0.3f",
            otf.version,afm.version,tfm.version)
    end
end)

-- experimental mechanism for Mojca:
--
-- fonts.definetypeface {
--     name         = "mainbodyfont-light",
--     preset       = "antykwapoltawskiego-light",
-- }
--
-- fonts.definetypeface {
--     name         = "mojcasfavourite",
--     preset       = "antykwapoltawskiego",
--     normalweight = "light",
--     boldweight   = "bold",
--     width        = "condensed",
-- }

local Shapes = {
    serif = "Serif",
    sans  = "Sans",
    mono  = "Mono",
}

local ctx_startfontclass       = context.startfontclass
local ctx_stopfontclass        = context.stopfontclass
local ctx_definefontsynonym    = context.definefontsynonym
local ctx_dofastdefinetypeface = context.dofastdefinetypeface

function fonts.definetypeface(name,t)
    if type(name) == "table" then
        -- {name=abc,k=v,...}
        t = name
    elseif t then
        if type(t) == "string" then
            -- "abc", "k=v,..."
            t = settings_to_hash(name)
        else
            -- "abc", {k=v,...}
        end
        t.name = t.name or name
    else
        -- "name=abc,k=v,..."
        t = settings_to_hash(name)
    end
    local p = t.preset and fonts.typefaces[t.preset] or { }
    local name         = t.name         or "unknowntypeface"
    local shortcut     = t.shortcut     or p.shortcut or "rm"
    local size         = t.size         or p.size     or "default"
    local shape        = t.shape        or p.shape    or "serif"
    local fontname     = t.fontname     or p.fontname or "unknown"
    local normalweight = t.normalweight or t.weight or p.normalweight or p.weight or "normal"
    local boldweight   = t.boldweight   or t.weight or p.boldweight   or p.weight or "normal"
    local normalwidth  = t.normalwidth  or t.width  or p.normalwidth  or p.width  or "normal"
    local boldwidth    = t.boldwidth    or t.width  or p.boldwidth    or p.width  or "normal"
    Shape = Shapes[shape] or "Serif"
    ctx_startfontclass { name }
        ctx_definefontsynonym( { formatters["%s"]          (Shape) }, { formatters["spec:%s-%s-regular-%s"] (fontname, normalweight, normalwidth) } )
        ctx_definefontsynonym( { formatters["%sBold"]      (Shape) }, { formatters["spec:%s-%s-regular-%s"] (fontname, boldweight,   boldwidth  ) } )
        ctx_definefontsynonym( { formatters["%sBoldItalic"](Shape) }, { formatters["spec:%s-%s-italic-%s"]  (fontname, boldweight,   boldwidth  ) } )
        ctx_definefontsynonym( { formatters["%sItalic"]    (Shape) }, { formatters["spec:%s-%s-italic-%s"]  (fontname, normalweight, normalwidth) } )
    ctx_stopfontclass()
    local settings = sequenced({ features= t.features },",")
    ctx_dofastdefinetypeface(name, shortcut, shape, size, settings)
end

implement {
    name      = "definetypeface",
    actions   = fonts.definetypeface,
    arguments = "2 strings"
}

function fonts.current() -- todo: also handle name
    return fontdata[currentfont()] or fontdata[0]
end

function fonts.currentid()
    return currentfont() or 0
end

-- for the moment here, this will become a chain of extras that is
-- hooked into the ctx registration (or scaler or ...)

local dimenfactors = number.dimenfactors

function helpers.dimenfactor(unit,id)
    if unit == "ex" then
        return id and exheights[id] or 282460 -- lm 10pt
    elseif unit == "em" then
        return id and emwidths [id] or 655360 -- lm 10pt
    else
        local du = dimenfactors[unit]
        return du and 1/du or tonumber(unit) or 1
    end
end

local function digitwidth(font) -- max(quad/2,wd(0..9))
    local tfmdata = fontdata[font]
    local parameters = tfmdata.parameters
    local width = parameters.digitwidth
    if not width then
        width = round(parameters.quad/2) -- maybe tex.scale
        local characters = tfmdata.characters
        for i=48,57 do
            local wd = round(characters[i].width)
            if wd > width then
                width = wd
            end
        end
        parameters.digitwidth = width
    end
    return width
end

helpers.getdigitwidth = digitwidth
helpers.setdigitwidth = digitwidth

--

function helpers.getparameters(tfmdata)
    local p = { }
    local m = p
    local parameters = tfmdata.parameters
    while true do
        for k, v in next, parameters do
            m[k] = v
        end
        parameters = getmetatable(parameters)
        parameters = parameters and parameters.__index
        if type(parameters) == "table" then
            m = { }
            p.metatable = m
        else
            break
        end
    end
    return p
end

if environment.initex then

    local function names(t)
        local nt = #t
        if nt > 0 then
            local n = { }
            for i=1,nt do
                n[i] = t[i].name
            end
            return concat(n," ")
        else
            return "-"
        end
    end

    statistics.register("font processing", function()
        local l = { }
        for what, handler in table.sortedpairs(handlers) do
            local features = handler and handler.features
            if features then
                l[#l+1] = format("[%s (base initializers: %s) (base processors: %s) (base manipulators: %s) (node initializers: %s) (node processors: %s) (node manipulators: %s)]",
                    what,
                    names(features.initializers.base),
                    names(features.processors  .base),
                    names(features.manipulators.base),
                    names(features.initializers.node),
                    names(features.processors  .node),
                    names(features.manipulators.node)
                )
            end
        end
        return concat(l, " | ")
    end)

end

-- redefinition

-- local hashes      = fonts.hashes
-- local emwidths    = hashes.emwidths
-- local exheights   = hashes.exheights

setmetatableindex(dimenfactors, function(t,k)
    if k == "ex" then
        return 1/exheights[currentfont()]
    elseif k == "em" then
        return 1/emwidths[currentfont()]
    elseif k == "pct" or k == "%" then
        return 1/(texget("hsize")/100)
    else
     -- error("wrong dimension: " .. (s or "?")) -- better a message
        return false
    end
end)

dimenfactors.ex   = nil
dimenfactors.em   = nil
dimenfactors["%"] = nil
dimenfactors.pct  = nil

--[[ldx--
<p>Before a font is passed to <l n='tex'/> we scale it. Here we also need
to scale virtual characters.</p>
--ldx]]--

do

    -- can become luat-tex.lua

    local texsetglyphdata = tex.setglyphdata
    local texgetglyphdata = tex.getglyphdata

    if not texsetglyphdata then

        local texsetattribute = tex.setattribute
        local texgetattribute = tex.getattribute

        texsetglyphdata = function(n) return texsetattribute(0,n) end
        texgetglyphdata = function()  return texgetattribute(0)   end

        tex.setglyphdata = texsetglyphdata
        tex.getglyphdata = texgetglyphdata

    end

    -- till here

    local setmacro = tokens.setters.macro

    function constructors.currentfonthasfeature(n)
        local f = fontdata[currentfont()]
        if not f then return end f = f.shared
        if not f then return end f = f.rawdata
        if not f then return end f = f.resources
        if not f then return end f = f.features
        return f and (f.gpos[n] or f.gsub[n])
    end

    local ctx_doifelse = commands.doifelse
    local ctx_doif     = commands.doif

    implement {
        name      = "doifelsecurrentfonthasfeature",
        actions   = { constructors.currentfonthasfeature, ctx_doifelse },
        arguments = "string"
    }

    local f_strip  = formatters["%0.2fpt"] -- normally this value is changed only once
    local stripper = lpeg.patterns.stripzeros

    local cache = { }

    local hows = {
        ["+"] = "add",
        ["-"] = "subtract",
        ["="] = "replace",
    }

    local function setfeature(how,parent,name,font) -- 0/1 test temporary for testing
        if not how or how == 0 then
            if trace_features and texgetglyphdata() ~= 0 then
                report_cummulative("font %!font:name!, reset",fontdata[font or true])
            end
            texsetglyphdata(0)
        elseif how == true or how == 1 then
            local hash = "feature > " .. parent
            local done = cache[hash]
            if trace_features and done then
                report_cummulative("font %!font:name!, revive %a : %!font:features!",fontdata[font or true],parent,setups[numbers[done]])
            end
            texsetglyphdata(done or 0)
        else
            local full = parent .. how .. name
            local hash = "feature > " .. full
            local done = cache[hash]
            if not done then
                local n = setups[full]
                if n then
                    -- already defined
                else
                    n = mergecontextfeatures(parent,name,how,full)
                end
                done = registercontextfeature(hash,full,how)
                cache[hash] = done
                if trace_features then
                    report_cummulative("font %!font:name!, %s %a : %!font:features!",fontdata[font or true],hows[how],full,setups[numbers[done]])
                end
            end
            texsetglyphdata(done)
        end
    end

    local function resetfeature()
        if trace_features and texgetglyphdata() ~= 0 then
            report_cummulative("font %!font:name!, reset",fontdata[true])
        end
        texsetglyphdata(0)
    end

    local function setfontfeature(tag)
        texsetglyphdata(contextnumber(tag))
    end

    local function resetfontfeature()
        texsetglyphdata(0)
    end

    implement {
        name      = "nbfs",
        arguments = "dimen",
        actions   = function(d)
            context(lpegmatch(stripper,f_strip(d/65536)))
        end
    }

    implement {
        name      = "featureattribute",
        arguments = "string",
        actions   = { contextnumber, context }
    }

    implement {
        name      = "setfontfeature",
        arguments = "string",
        actions   = setfontfeature,
    }

    implement {
        name      = "resetfontfeature",
     -- arguments = { 0, 0 },
        actions   = resetfontfeature,
    }

    implement {
        name      = "setfontofid",
        arguments = "integer",
        actions   = function(id)
            ctx_getvalue(csnames[id])
        end
    }

    implement {
        name      = "definefontfeature",
        arguments = "3 strings",
        actions   = presetcontext,
    }

    implement {
        name      = "doifelsefontfeature",
        arguments = "string",
        actions   = function(name) ctx_doifelse(contextnumber(name) > 1) end,
    }

    implement {
        name      = "doifunknownfontfeature",
        arguments = "string",
        actions   = function(name) ctx_doif(contextnumber(name) == 0) end,
    }

    implement {
        name      = "adaptfontfeature",
        arguments = "2 strings",
        actions   = adaptcontext
    }

    local function registerlanguagefeatures()
        local specifications = languages.data.specifications
        for i=1,#specifications do
            local specification = specifications[i]
            local language = specification.opentype
            if language then
                local script = specification.opentypescript or specification.script
                if script then
                    local context = specification.context
                    if type(context) == "table" then
                        for i=1,#context do
                            definecontext(context[i], { language = language, script = script})
                        end
                    elseif type(context) == "string" then
                       definecontext(context, { language = language, script = script})
                    end
                end
            end
        end
    end

    constructors.setfeature   = setfeature
    constructors.resetfeature = resetfeature

    implement { name = "resetfeature",    actions = resetfeature }
    implement { name = "addfeature",      actions = setfeature, arguments = { "'+'",  "string", "string" } }
    implement { name = "subtractfeature", actions = setfeature, arguments = { "'-'",  "string", "string" } }
    implement { name = "replacefeature",  actions = setfeature, arguments = { "'='",  "string", "string" } }
    implement { name = "revivefeature",   actions = setfeature, arguments = { true, "string" } }

    implement {
        name      = "featurelist",
        actions   = { fonts.specifiers.contexttostring, context },
        arguments = { "string", "'otf'", "string", "'yes'", "'no'", true }
    }

    implement {
        name    = "registerlanguagefeatures",
        actions = registerlanguagefeatures,
    }

end

-- a fontkern plug:

-- nodes.injections.installnewkern(nuts.pool.fontkern)

do

    local report = logs.reporter("otf","variants")

    local function replace(tfmdata,feature,value)
        local characters = tfmdata.characters
        local variants   = tfmdata.resources.variants
        if variants then
            local t = { }
            for k, v in sortedhash(variants) do
                t[#t+1] = formatters["0x%X (%i)"](k,k)
            end
            value = tonumber(value) or 0xFE00 -- 917762
            report("fontname : %s",tfmdata.properties.fontname)
            report("available: % t",t)
            local v = variants[value]
            if v then
                report("using    : %X (%i)",value,value)
                for k, v in next, v do
                    local c = characters[v]
                    if c then
                        characters[k] = c
                    end
                end
            else
                report("unknown  : %X (%i)",value,value)
            end
        end
    end

    registerotffeature {
        name         = 'variant',
        description  = 'unicode variant',
        manipulators = {
            base = replace,
            node = replace,
        }
    }

end

-- here (todo: closure)

-- make a closure (200 limit):

do

    local trace_analyzing = false  trackers.register("otf.analyzing", function(v) trace_analyzing = v end)

    local analyzers       = fonts.analyzers
    local methods         = analyzers.methods

    local unsetvalue      = attributes.unsetvalue

    local a_color         = attributes.private('color')
    local a_colormodel    = attributes.private('colormodel')
    local a_state         = attributes.private('state')
    local m_color         = attributes.list[a_color] or { }

    local glyph_code      = nodes.nodecodes.glyph

    local states          = analyzers.states

    local colornames = {
        [states.init] = "font:1",
        [states.medi] = "font:2",
        [states.fina] = "font:3",
        [states.isol] = "font:4",
        [states.mark] = "font:5",
        [states.rest] = "font:6",
        [states.rphf] = "font:1",
        [states.half] = "font:2",
        [states.pref] = "font:3",
        [states.blwf] = "font:4",
        [states.pstf] = "font:5",
    }

    -- todo: traversers
    -- todo: check attr_list so that we can use the same .. helper: setcolorattr

    local function markstates(head)
        if head then
            head = tonut(head)
            local model = getattr(head,a_colormodel) or 1
            for glyph in nextchar, head do
                local a = getprop(glyph,a_state)
                if a then
                    local name = colornames[a]
                    if name then
                        local color = m_color[name]
                        if color then
                            setattr(glyph,a_colormodel,model)
                            setattr(glyph,a_color,color)
                        end
                    end
                end
            end
        end
    end

    local function analyzeprocessor(head,font,attr)
        local tfmdata = fontdata[font]
        local script, language = otf.scriptandlanguage(tfmdata,attr)
        local action = methods[script]
        if not action then
            return head, false
        end
        if type(action) == "function" then
            local head, done = action(head,font,attr)
            if done and trace_analyzing then
                markstates(head)
            end
            return head, done
        end
        action = action[language]
        if action then
            local head, done = action(head,font,attr)
            if done and trace_analyzing then
                markstates(head)
            end
            return head, done
        else
            return head, false
        end
    end

    registerotffeature { -- adapts
        name       = "analyze",
        processors = {
            node     = analyzeprocessor,
        }
    }


    function methods.nocolor(head,font,attr)
        for n, c, f in nextchar, head do
            if not font or f == font then
                setattr(n,a_color,unsetvalue)
            end
        end
        return head, true
    end

end


local function purefontname(name)
    if type(name) == "number" then
        name = getfontname(name)
    end
    if type(name) == "string" then
       return basename(name)
    end
end

implement {
    name      = "purefontname",
    actions   = { purefontname, context },
    arguments = "string",
}

local sharedstorage = storage.shared

local list    = sharedstorage.bodyfontsizes        or { }
local unknown = sharedstorage.unknownbodyfontsizes or { }

sharedstorage.bodyfontsizes        = list
sharedstorage.unknownbodyfontsizes = unknown

implement {
    name      = "registerbodyfontsize",
    arguments = "string",
    actions   = function(size)
        list[size] = true
    end
}

interfaces.implement {
    name      = "registerunknownbodysize",
    arguments = "string",
    actions   = function(size)
        if not unknown[size] then
            interfaces.showmessage("fonts",14,size)
        end
        unknown[size] = true
    end,
}

implement {
    name      = "getbodyfontsizes",
    arguments = "string",
    actions   = function(separator)
        context(concat(sortedkeys(list),separator))
    end
}

implement {
    name      = "processbodyfontsizes",
    arguments = "string",
    actions   = function(command)
        local keys = sortedkeys(list)
        if command then
            local action = context[command]
            for i=1,#keys do
                action(keys[i])
            end
        else
            context(concat(keys,","))
        end
    end
}

implement {
    name      = "cleanfontname",
    actions   = { cleanname, context },
    arguments = "string"
}

implement {
    name      = "fontlookupinitialize",
    actions   = names.lookup,
    arguments = "string",
}

implement {
    name      = "fontlookupnoffound",
    actions   = { names.noflookups, context },
}

implement {
    name      = "fontlookupgetkeyofindex",
    actions   = { names.getlookupkey, context },
    arguments = { "string", "integer"}
}

implement {
    name      = "fontlookupgetkey",
    actions   = { names.getlookupkey, context },
    arguments = "string"
}

-- this might move to a runtime module:

function commands.showchardata(n)
    local tfmdata = fontdata[currentfont()]
    if tfmdata then
        if type(n) == "string" then
            n = utfbyte(n)
        end
        local chr = tfmdata.characters[n]
        if chr then
            report_status("%s @ %s => %U => %c => %s",tfmdata.properties.fullname,tfmdata.parameters.size,n,n,serialize(chr,false))
        end
    end
end

function commands.showfontparameters(tfmdata)
    -- this will become more clever
    local tfmdata = tfmdata or fontdata[currentfont()]
    if tfmdata then
        local parameters        = tfmdata.parameters
        local mathparameters    = tfmdata.mathparameters
        local properties        = tfmdata.properties
        local hasparameters     = parameters     and next(parameters)
        local hasmathparameters = mathparameters and next(mathparameters)
        if hasparameters then
            report_status("%s @ %s => text parameters => %s",properties.fullname,parameters.size,serialize(parameters,false))
        end
        if hasmathparameters then
            report_status("%s @ %s => math parameters => %s",properties.fullname,parameters.size,serialize(mathparameters,false))
        end
        if not hasparameters and not hasmathparameters then
            report_status("%s @ %s => no text parameters and/or math parameters",properties.fullname,parameters.size)
        end
    end
end

implement {
    name    = "currentdesignsize",
    actions = function()
        context(parameters[currentfont()].designsize)
    end
}

implement {
    name      = "doifelsefontpresent",
    actions   = { names.exists, commands.doifelse },
    arguments = "string"
}

-- we use 0xFE000+ and 0xFF000+ in math and for runtime (text) extensions we
-- use 0xFD000+

constructors.privateslots = constructors.privateslots or { }

storage.register("fonts/constructors/privateslots", constructors.privateslots, "fonts.constructors.privateslots")

do

    local privateslots    = constructors.privateslots
    local lastprivateslot = 0xFD000

    constructors.privateslots = setmetatableindex(privateslots,function(t,k)
        local v = lastprivateslot
        lastprivateslot = lastprivateslot + 1
        t[k] = v
        return v
    end)

    implement {
        name      = "getprivateglyphslot",
        actions   = function(name) context(privateslots[name]) end,
        arguments = "string",
    }

end

-- an extra helper

function helpers.getcoloredglyphs(tfmdata)
    if type(tfmdata) == "number" then
        tfmdata = fontdata[tfmdata]
    end
    if not tfmdata then
        tfmdata = fontdata[true]
    end
    local characters   = tfmdata.characters
    local descriptions = tfmdata.descriptions
    local collected    = { }
    for unicode, character in next, characters do
        local description = descriptions[unicode]
        if description and (description.colors or character.svg) then
            collected[#collected+1] = unicode
        end
    end
    table.sort(collected)
    return collected
end

-- for the font manual

statistics.register("body font sizes", function()
    if next(unknown) then
        return formatters["defined: % t, undefined: % t"](sortedkeys(list),sortedkeys(unknown))
    end
end)

statistics.register("used fonts",function()
    if trace_usage then
        local filename = file.nameonly(environment.jobname) .. "-fonts-usage.lua"
        if next(fontdata) then
            local files = { }
            local list  = { }
            for id, tfmdata in sortedhash(fontdata) do
                local filename = tfmdata.properties.filename
                if filename then
                    local filedata = files[filename]
                    if filedata then
                        filedata.instances = filedata.instances + 1
                    else
                        local rawdata  = tfmdata.shared and tfmdata.shared.rawdata
                        local metadata = rawdata and rawdata.metadata
                        files[filename] = {
                            instances = 1,
                            filename  = filename,
                            version   = metadata and metadata.version,
                            size      = rawdata and rawdata.size,
                        }
                    end
                else
                    -- what to do
                end
            end
            for k, v in sortedhash(files) do
                list[#list+1] = v
            end
            table.save(filename,list)
        else
            os.remove(filename)
        end
    end
end)

-- new

do

    local settings_to_array    = utilities.parsers.settings_to_array
 -- local namedcolorattributes = attributes.colors.namedcolorattributes
 -- local colorvalues          = attributes.colors.values

 -- implement {
 --     name      = "definefontcolorpalette",
 --     arguments = "2 strings",
 --     actions   = function(name,set)
 --         set = settings_to_array(set)
 --         for i=1,#set do
 --             local name = set[i]
 --             local space, color = namedcolorattributes(name)
 --             local values = colorvalues[color]
 --             if values then
 --                 set[i] = { r = values[3], g = values[4],  b = values[5] }
 --             else
 --                 set[i] = { r = 0, g = 0, b = 0 }
 --             end
 --         end
 --         otf.registerpalette(name,set)
 --     end
 -- }

    implement {
        name      = "definefontcolorpalette",
        arguments = "2 strings",
        actions   = function(name,set)
            otf.registerpalette(name,settings_to_array(set))
        end
    }

end

do

    local pattern = C((1-S("* "))^1) -- strips all after * or ' at'

    implement {
        name      = "truefontname",
        arguments = "string",
        actions   = function(s)
         -- context(match(s,"[^* ]+") or s)
            context(lpegmatch(pattern,s) or s)
        end
    }

end

do

    local function getinstancespec(id)
        local data      = fontdata[id or true]
        local shared    = data.shared
        local resources = shared and shared.rawdata.resources
        if resources then
            local instancespec = data.properties.instance
            if instancespec then
                local variabledata = resources.variabledata
                if variabledata then
                    local instances = variabledata.instances
                    if instances then
                        for i=1,#instances do
                            local instance = instances[i]
                            if cleanname(instance.subfamily)== instancespec then
                                local values = table.copy(instance.values)
                                local axis = variabledata.axis
                                for i=1,#values do
                                    for j=1,#axis do
                                        if values[i].axis == axis[j].tag then
                                            values[i].name = axis[j].name
                                            break
                                        end
                                    end
                                end
                                return values
                            end
                        end
                    end
                end
            end
        end
    end

    helpers.getinstancespec = getinstancespec

    implement {
        name      = "currentfontinstancespec",
        actions   = function()
            local t = getinstancespec() -- current font
            if t then
                for i=1,#t do
                    if i > 1 then
                        context.space()
                    end
                    local ti = t[i]
                    context("%s=%s",ti.name,ti.value)
                end
            end
        end
    }

end

-- for the moment here (and not in font-con.lua):

do

    local identical     = table.identical
    local copy          = table.copy
    local fontdata      = fonts.hashes.identifiers
    local addcharacters = font.addcharacters

    -- This helper is mostly meant to add last-resort (virtual) characters
    -- or runtime generated fonts (so we forget about features and such). It
    -- will probably take a while before it get used.

    local trace_adding  = false
    local report_adding = logs.reporter("fonts","add characters")

    trackers.register("fonts.addcharacters",function(v) trace_adding = v end)

    if addcharacters then

        function fonts.constructors.addcharacters(id,list)
            local newchar = list.characters
            if newchar then
                local data    = fontdata[id]
                local newfont = list.fonts
                local oldchar = data.characters
                local oldfont = data.fonts
                addcharacters(id, {
                    characters = newchar,
                    fonts      = newfont,
                    nomath     = not data.properties.hasmath,
                })
                -- this is just for tracing, as the assignment only uses the fonts list
                -- and doesn't store it otherwise
                if newfont then
                    if oldfont then
                        local oldn = #oldfont
                        local newn = #newfont
                        for n=1,newn do
                            local ok = false
                            local nf = newfont[n]
                            for o=1,oldn do
                                if identical(nf,oldfont[o]) then
                                    ok = true
                                    break
                                end
                            end
                            if not ok then
                                oldn = oldn + 1
                                oldfont[oldn] = newfont[i]
                            end
                        end
                    else
                        data.fonts = newfont
                    end
                end
                -- this is because we need to know what goes on and also might
                -- want to access character data
                for u, c in next, newchar do
                    if trace_adding then
                        report_adding("adding character %U to font %!font:name!",u,id)
                    end
                    oldchar[u] = c
                end
            end
        end

    else
        function fonts.constructors.addcharacters(id,list)
            report_adding("adding characters to %!font:name! is not yet supported",id)
        end
    end

    implement {
        name      = "addfontpath",
        arguments = "string",
        actions   = function(list)
            names.addruntimepath(settings_to_array(list))
        end
    }

end

-- moved here

do

    local getfontoffamily = font.getfontoffamily
    local new_glyph       = nodes.pool.glyph
    local fontproperties  = fonts.hashes.properties

    local function getprivateslot(id,name)
        if not name then
            name = id
            id   = currentfont()
        end
        local properties = fontproperties[id]
        local privates   = properties and properties.privates
        return privates and privates[name]
    end

    local function getprivatenode(tfmdata,name)
        if type(tfmdata) == "number" then
            tfmdata = fontdata[tfmdata]
        end
        local properties = tfmdata.properties
        local font = properties.id
        local slot = getprivateslot(font,name)
        if slot then
            -- todo: set current attribibutes
            local char   = tfmdata.characters[slot]
            local tonode = char.tonode
            if tonode then
                return tonode(font,char)
            else
                return new_glyph(font,slot)
            end
        end
    end

    local function getprivatecharornode(tfmdata,name)
        if type(tfmdata) == "number" then
            tfmdata = fontdata[tfmdata]
        end
        local properties = tfmdata.properties
        local font = properties.id
        local slot = getprivateslot(font,name)
        if slot then
            -- todo: set current attributes
            local char   = tfmdata.characters[slot]
            local tonode = char.tonode
            if tonode then
                return "node", tonode(tfmdata,char)
            else
                return "char", slot
            end
        end
    end

    helpers.getprivateslot       = getprivateslot
    helpers.getprivatenode       = getprivatenode
    helpers.getprivatecharornode = getprivatecharornode

    implement {
        name      = "getprivatechar",
        arguments = "string",
        actions   = function(name)
            local p = getprivateslot(name)
            if p then
                context(utfchar(p))
            end
        end
    }

    implement {
        name      = "getprivatemathchar",
        arguments = "string",
        actions   = function(name)
            local p = getprivateslot(getfontoffamily(0),name)
            if p then
                context(utfchar(p))
            end
        end
    }

    implement {
        name      = "getprivateslot",
        arguments = "string",
        actions   = function(name)
            local p = getprivateslot(name)
            if p then
                context(p)
            end
        end
    }

end

-- handy, for now here:

function fonts.helpers.collectanchors(tfmdata)

    local resources = tfmdata.resources -- todo: use shared

    if not resources or resources.anchors then
        return resources.anchors
    end

    local anchors = { }

    local function set(unicode,target,class,anchor)
        local a = anchors[unicode]
        if not a then
            anchors[unicode] = { [target] = { anchor } }
            return
        end
        local t = a[target]
        if not t then
            a[target] = { anchor }
            return
        end
        local x = anchor[1]
        local y = anchor[2]
        for k, v in next, t do
            if v[1] == x and v[2] == y then
                return
            end
        end
        t[#t+1] = anchor
    end

    local function getanchors(steps,target)
        for i=1,#steps do
            local step     = steps[i]
            local coverage = step.coverage
            for unicode, data in next, coverage do
                local class  = data[1]
                local anchor = data[2]
                if anchor[1] ~= 0 or anchor[2] ~= 0 then
                    set(unicode,target,class,anchor)
                end
            end
        end
    end

    local function getcursives(steps)
        for i=1,#steps do
            local step     = steps[i]
            local coverage = step.coverage
            for unicode, data in next, coverage do
                local class  = data[1]
                local en = data[2]
                local ex = data[3]
                if en then
                    set(unicode,"entry",class,en)
                end
                if ex then
                    set(unicode,"exit", class,ex)
                end
            end
        end
    end

    local function collect(list)
        if list then
            for i=1,#list do
                local entry = list[i]
                local steps = entry.steps
                local kind  = entry.type
                if kind == "gpos_mark2mark" then
                    getanchors(steps,"mark")
                elseif kind == "gpos_mark2base" then
                    getanchors(steps,"base")
                elseif kind == "gpos_mark2ligature" then
                    getanchors(steps,"ligature")
                elseif kind == "gpos_cursive" then
                    getcursives(steps)
                end
            end
        end
    end

    collect(resources.sequences)
    collect(resources.sublookups)

    local function sorter(a,b)
        if a[1] == b[1] then
            return a[2] < b[2]
        else
            return a[1] < b[1]
        end
    end

    for unicode, old in next, anchors do
        for target, list in next, old do
            sort(list,sorter)
        end
    end

    resources.anchors = anchors

    return anchors

end

if CONTEXTLMTXMODE > 0 then
    fonts.constructors.addtounicode = false
    fonts.constructors.autocleanup  = false
end
