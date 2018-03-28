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

-- todo: no foo:bar but foo(bar,...)

local type, tonumber, next = type, tonumber, next
local utfbyte = utf.byte
local format, gsub, gmatch, find = string.format, string.gsub, string.gmatch, string.find
local concat, sortedkeys, sortedpairs, keys, insert = table.concat, table.sortedkeys, table.sortedpairs, table.keys, table.insert
local utfbytes, strip, utfcharacters = string.utfvalues, string.strip, utf.characters

local context   = context
local commands  = commands
local implement = interfaces.implement

local settings_to_array = utilities.parsers.settings_to_array
local settings_to_set = utilities.parsers.settings_to_set

local trace_patterns = false  trackers.register("languages.patterns", function(v) trace_patterns = v end)

local report_initialization = logs.reporter("languages","initialization")

local lang             = lang

local prehyphenchar    = lang.prehyphenchar    -- global per language
local posthyphenchar   = lang.posthyphenchar   -- global per language
local preexhyphenchar  = lang.preexhyphenchar  -- global per language
local postexhyphenchar = lang.postexhyphenchar -- global per language
----- lefthyphenmin    = lang.lefthyphenmin
----- righthyphenmin   = lang.righthyphenmin
local sethjcode        = lang.sethjcode

local uccodes          = characters.uccodes
local lccodes          = characters.lccodes

lang.exceptions        = lang.hyphenation
local new_langage      = lang.new

languages              = languages or {}
local languages        = languages

languages.version      = 1.010

languages.registered   = languages.registered or { }
local registered       = languages.registered

languages.associated   = languages.associated or { }
local associated       = languages.associated

languages.numbers      = languages.numbers    or { }
local numbers          = languages.numbers

languages.data         = languages.data       or { }
local data             = languages.data

storage.register("languages/registered",registered,"languages.registered")
storage.register("languages/associated",associated,"languages.associated")
storage.register("languages/numbers",   numbers,   "languages.numbers")
storage.register("languages/data",      data,      "languages.data")

local variables = interfaces.variables

local v_reset   = variables.reset
local v_yes     = variables.yes

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

local function validdata(loaded,what,tag)
    local dataset = loaded[what]
    if dataset then
        local data = dataset.data
        if not data or data == "" then
            -- nothing
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

-- languages.hjcounts[unicode].count

-- hjcode: 0       not to be hyphenated
--         1--31   length
--         32      zero length
--         > 32    hyphenated with length 1

local function sethjcodes(instance,loaded,what,factor)
    local l = loaded[what]
    local c = l and l.characters
    if c then
        local hjcounts = factor and languages.hjcounts or false
        --
        local h = loaded.codehash
        if not h then
            h = { }
            loaded.codehash = h
        end
        --
        local function setcode(l)
            local u = uccodes[l]
            local s = l
            if hjcounts then
                local c = hjcounts[l]
                if c then
                    c = c.count
                    if not c then
                        -- error, keep as 1
                    elseif c <= 0 then
                        -- counts as 0 i.e. ignored
                        s = 32
                    elseif c >= 31 then
                        -- counts as 31
                        s = 31
                    else
                        -- count c times
                        s = c
                    end
                end
            end
            sethjcode(instance,l,s)
            h[l] = s
            if u ~= l and type(u) == "number" then
                sethjcode(instance,u,s)
                h[u] = lccodes[l]
            end
        end
        --
        local s = tex.savinghyphcodes
        tex.savinghyphcodes = 0
        if type(c) == "table" then
            for l in next, c do
                setcode(utfbyte(l))
            end
        else
            for l in utfbytes(c) do
                setcode(l)
            end
        end
        tex.savinghyphcodes = s
    end
end

-- 2'2 conflicts with 4' ... and luatex barks on it

local P, R, Cs, Ct, lpegmatch, lpegpatterns = lpeg.P, lpeg.R, lpeg.Cs, lpeg.Ct, lpeg.match, lpeg.patterns

local utfsplit = utf.split

local space       = lpegpatterns.space
local whitespace  = lpegpatterns.whitespace^1
local nospace     = lpegpatterns.utf8char - whitespace
local digit       = lpegpatterns.digit
----- endofstring = #whitespace + P(-1)
local endofstring = #whitespace

local word        = (digit/"")^0 * (digit/"" * endofstring + digit/" " + nospace)^1
local anyword     = (1-whitespace)^1
local analyze     = Ct((whitespace + Cs(word))^1)

local function unique(tag,requested,loaded)
    local nofloaded = #loaded
    if nofloaded == 0 then
        return ""
    elseif nofloaded == 1 then
        return loaded[1]
    else
        insert(loaded,1," ") -- no need then for special first word
     -- insert(loaded,  " ")
        loaded = concat(loaded," ")
        local t = lpegmatch(analyze,loaded) or { }
        local h = { }
        local b = { }
        for i=1,#t do
            local ti = t[i]
            local hi = h[ti]
            if not hi then
                h[ti] = 1
            elseif hi == 1 then
                h[ti] = 2
                b[#b+1] = utfsplit(ti," ")
            end
        end
        -- sort
        local nofbad = #b
        if nofbad > 0 then
            local word
            for i=1,nofbad do
                local bi = b[i]
                local p = P(bi[1])
                for i=2,#bi do
                    p = p * digit * P(bi[i])
                end
                if word then
                    word = word + p
                else
                    word = p
                end
                report_initialization("language %a, patterns %a, discarding conflict (0-9)%{[0-9]}t(0-9)",tag,requested,bi)
            end
            t, h, b = nil, nil, nil -- permit gc
            local someword = digit^0 * word * digit^0 * endofstring / ""
         -- local strip    = Cs(someword^-1 * (someword + anyword + whitespace)^1)
            local strip    = Cs((someword + anyword + whitespace)^1)
            return lpegmatch(strip,loaded) or loaded
        else
            return loaded
        end
    end
end

local shared = false

local function loaddefinitions(tag,specification)
    statistics.starttiming(languages)
    local data, instance = resolve(tag)
    local requested = specification.patterns or ""
    local definitions = settings_to_array(requested)
    if #definitions > 0 then
        if trace_patterns then
            report_initialization("pattern specification for language %a: %s",tag,specification.patterns)
        end
        local ploaded = instance:patterns()
        local eloaded = instance:hyphenation()
        if not ploaded or ploaded == ""  then
            ploaded = { }
        else
            ploaded = { ploaded }
        end
        if not eloaded or eloaded == ""  then
            eloaded = { }
        else
            eloaded = { eloaded }
        end
        local dataused  = data.used
        local ok        = false
        local resources = data.resources or { }
        data.resources  = resources
        if not shared then
            local found = resolvers.findfile("lang-exc.lua")
            if found then
                shared = dofile(found)
                if type(shared) == "table" then
                    shared = concat(shared," ")
                else
                    shared = true
                end
            else
                shared = true
            end
        end
        for i=1,#definitions do
            local definition = definitions[i]
            if definition == "" then
                -- error
            elseif definition == v_reset then
                if trace_patterns then
                    report_initialization("clearing patterns for language %a",tag)
                end
                instance:clear_patterns()
                instance:clear_hyphenation()
                ploaded = { }
                eloaded = { }
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
                        sethjcodes(instance,loaded,"patterns",specification.factor)
                        sethjcodes(instance,loaded,"exceptions",specification.factor)
                        local p = validdata(loaded,"patterns",tag)
                        local e = validdata(loaded,"exceptions",tag)
                        if p and p ~= "" then
                            ploaded[#ploaded+1] = p
                        end
                        if e and e ~= "" then
                            eloaded[#eloaded+1] = e
                        end
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
        if #ploaded > 0 then
            -- why not always clear
            instance:clear_patterns()
            instance:patterns(unique(tag,requested,ploaded))
        end
        if #eloaded > 0 then
            -- why not always clear
            instance:clear_hyphenation()
            instance:hyphenation(concat(eloaded," "))
        end
        if type(shared) == "string" then
            instance:hyphenation(shared)
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
    if not tag then
        tag = numbers[tex.language]
    elseif type(tag) == "number" then
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

    function languages.getnumber(tag,default,patterns,factor)
        local l = registered[tag]
        if l then
            if l.dirty then
                l.factor = factor == v_yes and true or false
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
-------- languages.lefthyphenmin   (what) return lefthyphenmin   (tolang(what)) end
-------- languages.righthyphenmin  (what) return righthyphenmin  (tolang(what)) end

-- e['implementer']= 'imple{m}{-}{-}menter'
-- e['manual'] = 'man{}{}{}'
-- e['as'] = 'a-s'
-- e['user-friendly'] = 'user=friend-ly'
-- e['exceptionally-friendly'] = 'excep-tionally=friend-ly'

local invalid = { "{", "}", "-" }

local function collecthjcodes(data,str)
    local found = data.extras and data.extras.characters or { }
    for s in utfcharacters(str) do
        if not found[s] then
            found[s] = true
        end
    end
    for i=1,#invalid do -- less checks this way
        local c = invalid[i]
        if found[c] then
            found[c] = nil
        end
    end
    data.extras = { characters = found }
    sethjcodes(data.instance,data,"extras",data.factor)
end

function languages.loadwords(tag,filename)
    local data, instance = resolve(tag)
    if data then
        statistics.starttiming(languages)
        local str = io.loaddata(filename) or ""
        collecthjcodes(data,str)
        instance:hyphenation(str)
        statistics.stoptiming(languages)
    end
end


function languages.setexceptions(tag,str)
    local data, instance = resolve(tag)
    if data then
        str = strip(str) -- we need to strip leading spaces
        collecthjcodes(data,str)
        instance:hyphenation(str)
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
    arguments = "4 strings"
}

implement {
    name      = "installedlanguages",
    actions   = { languages.installed, context },
}

implement {
    name      = "definelanguage",
    actions   = languages.define,
    arguments = "2 strings"
}

implement {
    name      = "setlanguagesynonym",
    actions   = languages.setsynonym,
    arguments = "2 strings"
}

implement {
    name      = "unloadlanguage",
    actions   = languages.unload,
    arguments = "string"
}

implement {
    name      = "setlanguageexceptions",
    actions   = languages.setexceptions,
    arguments = "2 strings"
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
