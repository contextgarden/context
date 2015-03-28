if not modules then modules = { } end modules ['lang-ini'] = {
    version   = 1.001,
    comment   = "companion to lang-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- needs a cleanup (share locals)
-- discard language when redefined

-- 002D : hyphen-minus (ascii)
-- 2010 : hyphen
-- 2011 : nonbreakable hyphen
-- 2013 : endash (compound hyphen)

--~ lang:hyphenation(string) string = lang:hyphenation() lang:clear_hyphenation()

local type, tonumber = type, tonumber
local utfbyte = utf.byte
local format, gsub = string.format, string.gsub
local concat, sortedkeys, sortedpairs = table.concat, table.sortedkeys, table.sortedpairs

local context   = context
local commands  = commands
local implement = interfaces.implement

local settings_to_array = utilities.parsers.settings_to_array

local trace_patterns = false  trackers.register("languages.patterns", function(v) trace_patterns = v end)

local report_initialization = logs.reporter("languages","initialization")

local prehyphenchar    = lang.prehyphenchar    -- global per language
local posthyphenchar   = lang.posthyphenchar   -- global per language
local preexhyphenchar  = lang.preexhyphenchar  -- global per language
local postexhyphenchar = lang.postexhyphenchar -- global per language
local lefthyphenmin    = lang.lefthyphenmin
local righthyphenmin   = lang.righthyphenmin

local lang           = lang
lang.exceptions      = lang.hyphenation
local new_langage    = lang.new

languages            = languages or {}
local languages      = languages

languages.version    = 1.010

languages.registered = languages.registered or { }
local registered     = languages.registered

languages.associated = languages.associated or { }
local associated     = languages.associated

languages.numbers    = languages.numbers    or { }
local numbers        = languages.numbers

languages.data       = languages.data       or { }
local data           = languages.data

storage.register("languages/registered",registered,"languages.registered")
storage.register("languages/associated",associated,"languages.associated")
storage.register("languages/numbers",   numbers,   "languages.numbers")
storage.register("languages/data",      data,      "languages.data")

local nofloaded  = 0

local function resolve(tag)
    local data, instance = registered[tag], nil
    if data then
        instance = data.instance
        if not instance then
            instance = new_langage(data.number)
            data.instance = instance
        end
    end
    return data, instance
end

local function tolang(what) -- returns lang object
    if not what then
        what = tex.language
    end
    local tag = numbers[what]
    local data = tag and registered[tag] or registered[what]
    if data then
        local instance = data.lang
        if not instance then
            instance = new_langage(data.number)
            data.instance = instance
        end
        return instance
    end
end

function languages.getdata(tag) -- or number
    if tag then
        return registered[tag] or registered[numbers[tag]]
    else
        return registered[numbers[tex.language]]
    end
end

-- languages.tolang = tolang

-- patterns=en
-- patterns=en,de

local function validdata(dataset,what,tag)
    if dataset then
        local data = dataset.data
        if not data or data == "" then
            return nil
        elseif dataset.compression == "zlib" then
            data = zlib.decompress(data)
            if dataset.length and dataset.length ~= #data then
                report_initialization("compression error in %a for language %a","patterns",what,tag)
            end
            return data
        else
            return data
        end
    end
end

local function loaddefinitions(tag,specification)
    statistics.starttiming(languages)
    local data, instance = resolve(tag)
    local definitions = settings_to_array(specification.patterns or "")
    if #definitions > 0 then
        if trace_patterns then
            report_initialization("pattern specification for language %a: %s",tag,specification.patterns)
        end
        local dataused  = data.used
        local ok        = false
        local resources = data.resources or { }
        data.resources  = resources
        for i=1,#definitions do
            local definition = definitions[i]
            if definition == "" then
                -- error
            elseif definition == "reset" then -- interfaces.variables.reset
                if trace_patterns then
                    report_initialization("clearing patterns for language %a",tag)
                end
                instance:clear_patterns()
            elseif not dataused[definition] then
                dataused[definition] = definition
                local filename = "lang-" .. definition .. ".lua"
                local fullname = resolvers.findfile(filename) or ""
                if fullname == "" then
                    fullname = resolvers.findfile(filename .. ".gz") or ""
                end
                if fullname ~= "" then
                    if trace_patterns then
                        report_initialization("loading definition %a for language %a from %a",definition,tag,fullname)
                    end
                    local suffix, gzipped = gzip.suffix(fullname)
                    local loaded = table.load(fullname,gzipped and gzip.load)
                    if loaded then -- todo: version test
                        ok, nofloaded = true, nofloaded + 1
                     -- instance:patterns   (loaded.patterns   and resources.patterns  .data or "")
                     -- instance:hyphenation(loaded.exceptions and resources.exceptions.data or "")
                        instance:patterns   (validdata(loaded.patterns,  "patterns",  tag) or "")
                        instance:hyphenation(validdata(loaded.exceptions,"exceptions",tag) or "")
                        resources[#resources+1] = loaded -- so we can use them otherwise

                    else
                        report_initialization("invalid definition %a for language %a in %a",definition,tag,filename)
                    end
                elseif trace_patterns then
                    report_initialization("invalid definition %a for language %a in %a",definition,tag,filename)
                end
            elseif trace_patterns then
                report_initialization("definition %a for language %a already loaded",definition,tag)
            end
        end
        return ok
    elseif trace_patterns then
        report_initialization("no definitions for language %a",tag)
    end
    statistics.stoptiming(languages)
end

storage.shared.noflanguages = storage.shared.noflanguages or 0

local noflanguages = storage.shared.noflanguages

function languages.define(tag,parent)
    noflanguages = noflanguages + 1
    if trace_patterns then
        report_initialization("assigning number %a to %a",noflanguages,tag)
    end
    numbers[noflanguages] = tag
    registered[tag] = {
        tag      = tag,
        parent   = parent or "",
        patterns = "",
        loaded   = false,
        used     = { },
        dirty    = true,
        number   = noflanguages,
        instance = nil, -- luatex data structure
        synonyms = { },
    }
    storage.shared.noflanguages = noflanguages
end

function languages.setsynonym(synonym,tag) -- convenience function
    local l = registered[tag]
    if l then
        l.synonyms[synonym] = true -- maybe some day more info
    end
end

function languages.installed(separator)
    return concat(sortedkeys(registered),separator or ",")
end

function languages.current(n)
    return numbers[n and tonumber(n) or tex.language]
end

function languages.associate(tag,script,language) -- not yet used
    associated[tag] = { script, language }
end

function languages.association(tag) -- not yet used
    if type(tag) == "number" then
        tag = numbers[tag]
    end
    local lat = tag and associated[tag]
    if lat then
        return lat[1], lat[2]
    end
end

function languages.loadable(tag,defaultlanguage) -- hack
    local l = registered[tag] -- no synonyms
    if l and resolvers.findfile("lang-"..l.patterns..".lua") then
        return true
    else
        return false
    end
end

-- a bit messy, we will do all language setting in lua as we can now assign
-- and 'patterns' will go away here.

function languages.unload(tag)
    local l = registered[tag]
    if l then
        l.dirty = true
    end
end

if environment.initex then

    function languages.getnumber()
        return 0
    end

else

    function languages.getnumber(tag,default,patterns)
        local l = registered[tag]
        if l then
            if l.dirty then
                if trace_patterns then
                    report_initialization("checking patterns for %a with default %a",tag,default)
                end
                -- patterns is already resolved to parent patterns if applicable
                if patterns and patterns ~= "" then
                    if l.patterns ~= patterns then
                        l.patterns = patterns
                        if trace_patterns then
                            report_initialization("loading patterns for %a using specification %a",tag,patterns)
                        end
                        loaddefinitions(tag,l)
                    else
                        -- unchanged
                    end
                elseif l.patterns == "" then
                    l.patterns = tag
                    if trace_patterns then
                        report_initialization("loading patterns for %a using tag",tag)
                    end
                    local ok = loaddefinitions(tag,l)
                    if not ok and tag ~= default then
                        l.patterns = default
                        if trace_patterns then
                            report_initialization("loading patterns for %a using default",tag)
                        end
                        loaddefinitions(tag,l)
                    end
                end
                l.loaded = true
                l.dirty = false
            end
            return l.number
        else
            return 0
        end
    end

end

-- not that usefull, global values

function languages.prehyphenchar   (what) return prehyphenchar   (tolang(what)) end
function languages.posthyphenchar  (what) return posthyphenchar  (tolang(what)) end
function languages.preexhyphenchar (what) return preexhyphenchar (tolang(what)) end
function languages.postexhyphenchar(what) return postexhyphenchar(tolang(what)) end
function languages.lefthyphenmin   (what) return lefthyphenmin   (tolang(what)) end
function languages.righthyphenmin  (what) return righthyphenmin  (tolang(what)) end

-- e['implementer']= 'imple{m}{-}{-}menter'
-- e['manual'] = 'man{}{}{}'
-- e['as'] = 'a-s'
-- e['user-friendly'] = 'user=friend-ly'
-- e['exceptionally-friendly'] = 'excep-tionally=friend-ly'

function languages.loadwords(tag,filename)
    local data, instance = resolve(tag)
    if data then
        statistics.starttiming(languages)
        instance:hyphenation(io.loaddata(filename) or "")
        statistics.stoptiming(languages)
    end
end

function languages.setexceptions(tag,str)
    local data, instance = resolve(tag)
    if data then
        instance:hyphenation(string.strip(str)) -- we need to strip leading spaces
    end
end

function languages.hyphenate(tag,str)
    -- todo: does this still work?
    local data, instance = resolve(tag)
    if data then
        return instance:hyphenate(str)
    else
        return str
    end
end

-- hyphenation.define        ("zerolanguage")
-- hyphenation.loadpatterns  ("zerolanguage") -- else bug
-- hyphenation.loadexceptions("zerolanguage") -- else bug

languages.logger = languages.logger or { }

function languages.logger.report()
    local result, r = { }, 0
    for tag, l in sortedpairs(registered) do
        if l.loaded then
            r = r + 1
            result[r] = format("%s:%s:%s",tag,l.parent,l.number)
        end
    end
    return r > 0 and concat(result," ") or "none"
end

-- must happen at the tex end .. will use lang-def.lua

languages.associate('en','latn','eng')
languages.associate('uk','latn','eng')
languages.associate('nl','latn','nld')
languages.associate('de','latn','deu')
languages.associate('fr','latn','fra')

statistics.register("loaded patterns", function()
    local result = languages.logger.report()
    if result ~= "none" then
     -- return result
        return format("%s, load time: %s",result,statistics.elapsedtime(languages))
    end
end)

-- statistics.register("language load time", function()
--     -- often zero so we can merge that in the above
--     return statistics.elapsedseconds(languages, format(", nofpatterns: %s",nofloaded))
-- end)

-- interface

implement {
    name      = "languagenumber",
    actions   = { languages.getnumber, context },
    arguments = { "string", "string", "string" }
}

implement {
    name      = "installedlanguages",
    actions   = { languages.installed, context },
}

implement {
    name      = "definelanguage",
    actions   = languages.define,
    arguments = { "string", "string" }
}

implement {
    name      = "setlanguagesynonym",
    actions   = languages.setsynonym,
    arguments = { "string", "string" }
}

implement {
    name      = "unloadlanguage",
    actions   = languages.unload,
    arguments = { "string" }
}

implement {
    name      = "setlanguageexceptions",
    actions   = languages.setexceptions,
    arguments = { "string", "string" }
}


implement {
    name      = "currentprehyphenchar",
    actions   = function()
        local c = prehyphenchar(tolang())
        if c and c > 0 then
            context.char(c)
        end
    end
}

implement {
    name      = "currentposthyphenchar",
    actions   = function()
        local c = posthyphenchar(tolang())
        if c and c > 0 then
            context.char(c)
        end
    end
}
