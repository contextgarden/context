if not modules then modules = { } end modules ['lang-hyp'] = {
    version   = 1.001,
    comment   = "companion to lang-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- In an automated workflow hypenation of long titles can be somewhat problematic
-- especially when demands conflict. For that reason I played a bit with a Lua based
-- variant of the traditional hyphenation machinery. This mechanism has been extended
-- several times in projects, of which a good description can be found in TUGboat,
-- Volume 27 (2006), No. 2 — Proceedings of EuroTEX2006: Automatic non-standard
-- hyphenation in OpenOffice.org by László Németh.
--
-- Being the result of two days experimenting the following implementation is probably
-- not completely okay yet. If there is demand I might add some more features and plugs.
-- The performance is quite okay but can probably improved a bit, although this is not
-- the most critital code. For instance, on a metafun manual run the overhead is about
-- 0.3 seconds on 19 seconds which is not that bad.
--
-- In the procecess of wrapping up (for the ctx conference proceedings) I cleaned up
-- and extended the code a bit. It can be used in production.
--
-- . a l g o r i t h m .
--    4l1g4
--     l g o3
--      1g o
--            2i t h
--                4h1m
-- ---------------------
--    4 1 4 3 2 0 4 1
--   a l-g o-r i t h-m

-- . a s s z o n n y a l .
--     s1s z/sz=sz,1,3
--             n1n y/ny=ny,1,3
-- -----------------------
--    0 1 0 0 0 1 0 0 0/sz=sz,2,3,ny=ny,6,3
--   a s-s z o n-n y a l/sz=sz,2,3,ny=ny,6,3
--
-- ab1cd/ef=gh,2,2 : acd - efd (pattern/replacement,start,length
--
-- todo  : support hjcodes (<32 == length) like luatex does now (no need/demand so far)
-- maybe : support hyphenation over range (can alsready be done using attributes/language)
-- maybe : reset dictionary.hyphenated when a pattern is added and/or forced reset option
-- todo  : check subtypes (because they have subtle meanings in the line breaking)
--
-- word start (in tex engine):
--
-- boundary  : yes when wordboundary
-- hlist     : when hyphenationbounds 1 or 3
-- vlist     : when hyphenationbounds 1 or 3
-- rule      : when hyphenationbounds 1 or 3
-- dir       : when hyphenationbounds 1 or 3
-- whatsit   : when hyphenationbounds 1 or 3
-- glue      : yes
-- math      : skipped
-- glyph     : exhyphenchar (one only) : yes (so no -- ---)
-- otherwise : yes
--
-- word end (in tex engine):
--
-- boundary  : yes
-- glyph     : yes when different language
-- glue      : yes
-- penalty   : yes
-- kern      : yes when not italic (for some historic reason)
-- hlist     : when hyphenationbounds 2 or 3
-- vlist     : when hyphenationbounds 2 or 3
-- rule      : when hyphenationbounds 2 or 3
-- dir       : when hyphenationbounds 2 or 3
-- whatsit   : when hyphenationbounds 2 or 3
-- ins       : when hyphenationbounds 2 or 3
-- adjust    : when hyphenationbounds 2 or 3

local type, rawget, rawset, tonumber, next = type, rawget, rawset, tonumber, next

local P, R, S, Cg, Cf, Ct, Cc, C, Carg, Cs = lpeg.P, lpeg.R, lpeg.S, lpeg.Cg, lpeg.Cf, lpeg.Ct, lpeg.Cc, lpeg.C, lpeg.Carg, lpeg.Cs
local lpegmatch = lpeg.match

local context    = context

local concat     = table.concat
local insert     = table.insert
local remove     = table.remove
local formatters = string.formatters
local utfchar    = utf.char
local utfbyte    = utf.byte

if not characters then
    require("char-ini")
end

local setmetatableindex = table.setmetatableindex

-- \enabletrackers[hyphenator.steps=silent] will not write to the terminal

local trace_steps       = false  trackers.register("hyphenator.steps",    function(v) trace_steps     = v end)
local trace_visualize   = false  trackers.register("hyphenator.visualize",function(v) trace_visualize = v end)

local report            = logs.reporter("hyphenator")

local implement         = interfaces and interfaces.implement or function() end

languages               = languages or { }
local hyphenators       = languages.hyphenators or { }
languages.hyphenators   = hyphenators
local traditional       = hyphenators.traditional or { }
hyphenators.traditional = traditional

local dictionaries = setmetatableindex(function(t,k)
    local v = {
        patterns   = { },
        hyphenated = { },
        specials   = { },
        exceptions = { },
        loaded     = false,
    }
    t[k] = v
    return v
end)

hyphenators.dictionaries = dictionaries

local character      = lpeg.patterns.utf8character
local digit          = R("09")
local weight         = digit/tonumber + Cc(0)
local fence          = P(".")
local hyphen         = P("-")
local space          = P(" ")
local char           = character - space
local validcharacter = (character - S("./"))
local keycharacter   =  character - S("/")
----- basepart       = Ct( (Cc(0) * fence)^-1 * (weight * validcharacter)^1 * weight * (fence * Cc(0))^-1)
local specpart       = (P("/") * Cf ( Ct("") *
        Cg ( Cc("before") * C((1-P("="))^1) * P("=") ) *
        Cg ( Cc("after")  * C((1-P(","))^1)  ) *
        (   P(",") *
            Cg ( Cc("start")  * ((1-P(","))^1/tonumber) * P(",") ) *
            Cg ( Cc("length") * ((1-P(-1) )^1/tonumber)          )
        )^-1
    , rawset))^-1

local make_hashkey_p = Cs((digit/"" + keycharacter)^1)
----- make_pattern_p = basepart * specpart
local make_hashkey_e = Cs((hyphen/"" + keycharacter)^1)
local make_pattern_e = Ct(P(char) * (hyphen * Cc(true) * P(char) + P(char) * Cc(false))^1) -- catch . and char after -

-- local make_hashkey_c = Cs((digit + keycharacter/"")^1)
-- local make_pattern_c = Ct((P(1)/tonumber)^1)

-- local cache = setmetatableindex(function(t,k)
--     local n = lpegmatch(make_hashkey_c,k)
--     local v = lpegmatch(make_pattern_c,n)
--     t[k] = v
--     return v
-- end)
--
-- local weight_n       = digit + Cc("0")
-- local basepart_n     = Cs( (Cc("0") * fence)^-1 * (weight * validcharacter)^1 * weight * (fence * Cc("0"))^-1) / cache
-- local make_pattern_n = basepart_n * specpart

local make_pattern_c = Ct((P(1)/tonumber)^1)

-- us + nl: 17664 entries -> 827 unique (saves some 3M)

local cache = setmetatableindex(function(t,k)
    local v = lpegmatch(make_pattern_c,k)
    t[k] = v
    return v
end)

local weight_n       = digit + Cc("0")
local fence_n        = fence / "0"
local char_n         = validcharacter / ""
local basepart_n     = Cs(fence_n^-1 * (weight_n * char_n)^1 * weight_n * fence_n^-1) / cache
local make_pattern_n = basepart_n * specpart

local function register_pattern(patterns,specials,str,specification)
    local k = lpegmatch(make_hashkey_p,str)
 -- local v1, v2 = lpegmatch(make_pattern_p,str)
    local v1, v2 = lpegmatch(make_pattern_n,str)
    patterns[k] = v1 -- is this key still ok for complex patterns
    if specification then
        specials[k] = specification
    elseif v2 then
        specials[k] = v2
    end
end

local function unregister_pattern(patterns,specials,str)
    local k = lpegmatch(make_hashkey_p,str)
    patterns[k] = nil
    specials[k] = nil
end

local p_lower = lpeg.patterns.utf8lower

local function register_exception(exceptions,str,specification)
    local l = lpegmatch(p_lower,str)
    local k = lpegmatch(make_hashkey_e,l)
    local v = lpegmatch(make_pattern_e,l)
    exceptions[k] = v
end

local p_pattern   = ((Carg(1) * Carg(2) * C(char^1)) / register_pattern   + 1)^1
local p_exception = ((Carg(1)           * C(char^1)) / register_exception + 1)^1
local p_split     = Ct(C(character)^1)

function traditional.loadpatterns(language,filename)
    local dictionary    = dictionaries[language]
    if not dictionary.loaded then
        if not filename or filename == "" then
            filename = "lang-" .. language
        end
        filename = file.addsuffix(filename,"lua")
        local fullname = resolvers.findfile(filename)
        if fullname and fullname ~= "" then
            local specification = dofile(fullname)
            if specification then
                local patterns = specification.patterns
                if patterns then
                    local data = patterns.data
                    if data and data ~= "" then
                        lpegmatch(p_pattern,data,1,dictionary.patterns,dictionary.specials)
                    end
                end
                local exceptions = specification.exceptions
                if exceptions then
                    local data = exceptions.data
                    if data and data ~= "" then
                        lpegmatch(p_exception,data,1,dictionary.exceptions)
                    end
                end
            end
        end
        dictionary.loaded = true
    end
    return dictionary
end

local lcchars    = characters.lcchars
local uccodes    = characters.uccodes
local categories = characters.categories
local nofwords   = 0
local nofhashed  = 0

local steps     = nil
local f_show    = formatters["%w%s"]

local function show_log()
    if trace_steps == true then
        report()
        local w = #steps[1][1]
        for i=1,#steps do
            local s = steps[i]
            report("%s%w%S  %S",s[1],w - #s[1] + 3,s[2],s[3] or "")
        end
        report()
    end
end

local function show_1(wsplit)
    local u = concat(wsplit," ")
    steps = { { f_show(0,u), f_show(0,u) } }
end

local function show_2(c,m,wsplit,done,i,spec)
    local s = lpegmatch(p_split,c)
    local t = { }
    local n = #m
    local w = #wsplit
    for j=1,n do
        t[#t+1] = m[j]
        t[#t+1] = s[j]
    end
    local m = 2*i-2
    local l = #t
    local s = spec and table.sequenced(spec) or ""
    if m == 0 then
        steps[#steps+1] = { f_show(m,  concat(t,"",2)),      f_show(1,concat(done," ",2,#done),s) }
    elseif i+1 == w then
        steps[#steps+1] = { f_show(m-1,concat(t,"",1,#t-1)), f_show(1,concat(done," ",2,#done),s) }
    else
        steps[#steps+1] = { f_show(m-1,concat(t)),           f_show(1,concat(done," ",2,#done),s) }
    end
end

local function show_3(wsplit,done)
    local t = { }
    local h = { }
    local n = #wsplit
    for i=1,n do
        local w = wsplit[i]
        if i > 1 then
            local d = done[i]
            t[#t+1] = i > 2 and d % 2 == 1 and "-" or " "
            h[#h+1] = d
        end
        t[#t+1] = w
        h[#h+1] = w
    end
    steps[#steps+1] = { f_show(0,concat(h)), f_show(0,concat(t)) }
    show_log()
end

local function show_4(wsplit,done)
    steps = { { concat(wsplit," ") } }
    show_log()
end

function traditional.lasttrace()
    return steps
end

-- We could reuse the w table but as we cache the resolved words there is not much gain in
-- that complication.
--
-- Beware: word can be a table and when n is passed to we can assume reuse so we need to
-- honor that n then.
--
-- todo: a fast variant for tex ... less lookups (we could check is dictionary has changed)
-- ... although due to caching the already done words, we don't do much here

local function hyphenate(dictionary,word,n) -- odd is okay
    nofwords = nofwords + 1
    local hyphenated = dictionary.hyphenated
    local isstring = type(word) == "string"
    if isstring then
        local done = hyphenated[word]
        if done ~= nil then
            return done
        end
    elseif n then
        local done = hyphenated[concat(word,"",1,n)]
        if done ~= nil then
            return done
        end
    else
        local done = hyphenated[concat(word)]
        if done ~= nil then
            return done
        end
    end
    local key
    if isstring then
        key = word
        word = lpegmatch(p_split,word)
        if not n then
            n = #word
        end
    else
        if not n then
            n = #word
        end
        key = concat(word,"",1,n)
    end
    local l = 1
    local w = { "." }
 -- local d = dictionary.codehash
    for i=1,n do
        local c = word[i]
     -- l = l + (d[c] or 1)
        l = l + 1
        w[l] = lcchars[c] or c
    end
    l = l + 1
    w[l] = "."
    local c = concat(w,"",2,l-1)
    --
    local done = hyphenated[c]
    if done ~= nil then
        hyphenated[key] = done
        nofhashed = nofhashed + 1
        return done
    end
    --
    local exceptions = dictionary.exceptions
    local exception  = exceptions[c]
    if exception then
        if trace_steps then
            show_4(w,exception)
        end
        hyphenated[key] = exception
        nofhashed = nofhashed + 1
        return exception
    end
    --
    if trace_steps then
        show_1(w)
    end
    --
    local specials = dictionary.specials
    local patterns = dictionary.patterns
    --
    local spec
    for i=1,l do
        for j=i,l do
            local c = concat(w,"",i,j)
            local m = patterns[c]
            if m then
                local s = specials[c]
                if not done then
                    done = { }
                    spec = nil
                    -- the string that we resolve has explicit fences (.) so done starts at
                    -- the first fence and runs upto the last one so we need one slot less
                    for i=1,l do
                        done[i] = 0
                    end
                end
                -- we run over the pattern that always has a (zero) value for each character
                -- plus one more as we look at both sides
                for k=1,#m do
                    local new = m[k]
                    if not new then
                        break
                    elseif new == true then
                        report("fatal error")
                        break
                    elseif new > 0 then
                        local pos = i + k - 1
                        local old = done[pos]
                        if not old then
                            -- break ?
                        elseif new > old then
                            done[pos] = new
                            if s then
                                local b = i + (s.start or 1) - 1
                                if b > 0 then
                                    local e = b + (s.length or 2) - 1
                                    if e > 0 then
                                        if pos >= b and pos <= e then
                                            if spec then
                                                spec[pos] = { s, k - 1 }
                                            else
                                                spec = { [pos] = { s, k - 1 } }
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
                if trace_steps and done then
                    show_2(c,m,w,done,i,s)
                end
            end
        end
    end
    if trace_steps and done then
        show_3(w,done)
    end
    if done then
        local okay = false
        for i=3,#done do
            if done[i] % 2 == 1 then
                done[i-2] = spec and spec[i] or true
                okay = true
            else
                done[i-2] = false
            end
        end
        if okay then
            done[#done] = nil
            done[#done] = nil
        else
            done = false
        end
    else
        done = false
    end
    hyphenated[key] = done
    nofhashed = nofhashed + 1
    return done
end

function traditional.gettrace(language,word)
    if not word or word == "" then
        return
    end
    local dictionary = dictionaries[language]
    if dictionary then
        local hyphenated = dictionary.hyphenated
        hyphenated[word] = nil
        hyphenate(dictionary,word)
        return steps
    end
end

local methods = setmetatableindex(function(t,k) local v = hyphenate t[k] = v return v end)

function traditional.installmethod(name,f)
    if rawget(methods,name) then
        report("overloading %a is not permitted",name)
    else
        methods[name] = f
    end
end

local s_detail_1 = "-"
local f_detail_2 = formatters["%s-%s"]
local f_detail_3 = formatters["{%s}{%s}{}"]
local f_detail_4 = formatters["{%s%s}{%s%s}{%s}"]

function traditional.injecthyphens(dictionary,word,specification)
    if not word then
        return false
    end
    if not specification then
        return word
    end
    local hyphens = hyphenate(dictionary,word)
    if not hyphens then
        return word
    end

    -- the following code is similar to code later on but here we have strings while there
    -- we have hyphen specs

    local word      = lpegmatch(p_split,word)
    local size      = #word

    local leftmin   = specification.leftcharmin or 2
    local rightmin  = size - (specification.rightcharmin or leftmin)
    local leftchar  = specification.leftchar
    local rightchar = specification.rightchar

    local result    = { }
    local rsize     = 0
    local position  = 1

    while position <= size do
        if position >= leftmin and position <= rightmin then
            local hyphen = hyphens[position]
            if not hyphen then
                rsize = rsize + 1
                result[rsize] = word[position]
                position = position + 1
            elseif hyphen == true then
                rsize = rsize + 1
                result[rsize] = word[position]
                rsize = rsize + 1
                if leftchar and rightchar then
                    result[rsize] = f_detail_3(rightchar,leftchar)
                else
                    result[rsize] = s_detail_1
                end
                position = position + 1
            else
                local o, h = hyphen[2]
                if o then
                    h = hyphen[1]
                else
                    h = hyphen
                    o = 1
                end
                local b = position - o + (h.start  or 1)
                local e = b + (h.length or 2) - 1
                if b > 0 and e >= b then
                    for i=1,b-position do
                        rsize = rsize + 1
                        result[rsize] = word[position]
                        position = position + 1
                    end
                    rsize = rsize + 1
                    if leftchar and rightchar then
                        result[rsize] = f_detail_4(h.before,rightchar,leftchar,h.after,concat(word,"",b,e))
                    else
                        result[rsize] = f_detail_2(h.before,h.after)
                    end
                    position = e + 1
                else
                    -- error
                    rsize = rsize + 1
                    result[rsize] = word[position]
                    position = position + 1
                end
            end
        else
            rsize = rsize + 1
            result[rsize] = word[position]
            position = position + 1
        end
    end
    return concat(result)
end

do

    local word      = C((1-space)^1)
    local spaces    = space^1

    local u_pattern = (Carg(1) * Carg(2) * word           / unregister_pattern + spaces)^1
    local r_pattern = (Carg(1) * Carg(2) * word * Carg(3) /   register_pattern + spaces)^1
    local e_pattern = (Carg(1)           * word           / register_exception + spaces)^1

    function traditional.registerpattern(language,str,specification)
        local dictionary = dictionaries[language]
        if specification == false then
            lpegmatch(u_pattern,str,1,dictionary.patterns,dictionary.specials)
         -- unregister_pattern(dictionary.patterns,dictionary.specials,str)
        else
            lpegmatch(r_pattern,str,1,dictionary.patterns,dictionary.specials,type(specification) == "table" and specification or false)
         -- register_pattern(dictionary.patterns,dictionary.specials,str,specification)
        end
    end

    function traditional.registerexception(language,str)
        lpegmatch(e_pattern,str,1,dictionaries[language].exceptions)
    end

end

-- todo: unicodes or utfhash ?

if context then

    local nodecodes          = nodes.nodecodes
    local disccodes          = nodes.disccodes

    local glyph_code         = nodecodes.glyph
    local disc_code          = nodecodes.disc
    local math_code          = nodecodes.math
    local hlist_code         = nodecodes.hlist

    local automaticdisc_code = disccodes.automatic
    local regulardisc_code   = disccodes.regular

    local nuts               = nodes.nuts
    local tonode             = nodes.tonode
    local nodepool           = nuts.pool

    local new_disc           = nodepool.disc
    local new_penalty        = nodepool.penalty

    local getfield           = nuts.getfield
    local getfont            = nuts.getfont
    local getid              = nuts.getid
    local getattr            = nuts.getattr
    local getnext            = nuts.getnext
    local getprev            = nuts.getprev
    local getsubtype         = nuts.getsubtype
    local getlist            = nuts.getlist
    local getlang            = nuts.getlang
    local getattrlist        = nuts.getattrlist
    local setattrlist        = nuts.setattrlist
    local isglyph            = nuts.isglyph
    local ischar             = nuts.ischar

    local setchar            = nuts.setchar
    local setdisc            = nuts.setdisc
    local setlink            = nuts.setlink
    local setprev            = nuts.setprev
    local setnext            = nuts.setnext

    local insert_before      = nuts.insert_before
    local insert_after       = nuts.insert_after
    local copy_node          = nuts.copy
    local copy_list          = nuts.copy_list
    local remove_node        = nuts.remove
    local end_of_math        = nuts.end_of_math
    local node_tail          = nuts.tail

    local nexthlist          = nuts.traversers.hlist
    local nextdisc           = nuts.traversers.disc

    local setcolor           = nodes.tracers.colors.set

    local variables          = interfaces.variables
    local v_reset            = variables.reset
    local v_yes              = variables.yes
    local v_word             = variables.word
    local v_all              = variables.all

    local settings_to_array  = utilities.parsers.settings_to_array

    local unsetvalue         = attributes.unsetvalue
    local texsetattribute    = tex.setattribute

    local prehyphenchar      = lang.prehyphenchar
    local posthyphenchar     = lang.posthyphenchar
    local preexhyphenchar    = lang.preexhyphenchar
    local postexhyphenchar   = lang.postexhyphenchar

    local a_hyphenation      = attributes.private("hyphenation")

    local interwordpenalty   = 5000

    function traditional.loadpatterns(language)
        return dictionaries[language]
    end

    -- for the moment we use an independent data structure

    setmetatableindex(dictionaries,function(t,k)
        if type(k) == "string" then
            -- this will force a load if not yet loaded (we need a nicer way) for the moment
            -- that will do (nneeded for examples that register a pattern specification
            languages.getnumber(k)
        end
        local specification = languages.getdata(k)
        local dictionary = {
            patterns   = { },
            exceptions = { },
            hyphenated = { },
            specials   = { },
            instance   = false,
            characters = { },
            unicodes   = { },
        }
        if specification then
            local resources = specification.resources
            if resources then
                local characters = dictionary.characters or { }
                local unicodes   = dictionary.unicodes   or { }
                for i=1,#resources do
                    local r = resources[i]
                    if not r.in_dictionary then
                        r.in_dictionary = true
                        local patterns = r.patterns
                        if patterns then
                            local data = patterns.data
                            if data then
                                -- regular patterns
                                lpegmatch(p_pattern,data,1,dictionary.patterns,dictionary.specials)
                            end
                            local extra = patterns.extra
                            if extra then
                                -- special patterns
                                lpegmatch(p_pattern,extra,1,dictionary.patterns,dictionary.specials)
                            end
                        end
                        local exceptions = r.exceptions
                        if exceptions then
                            local data = exceptions.data
                            if data and data ~= "" then
                                lpegmatch(p_exception,data,1,dictionary.exceptions)
                            end
                        end
                        local usedchars  = lpegmatch(p_split,patterns.characters)
                        for i=1,#usedchars do
                            local char  = usedchars[i]
                            local code  = utfbyte(char)
                            local upper = uccodes[code]
                            characters[char]  = code
                            unicodes  [code]  = char
                            if type(upper) == "table" then
                                for i=1,#upper do
                                    local u = upper[i]
                                    unicodes[u] = utfchar(u)
                                end
                            else
                                unicodes[upper] = utfchar(upper)
                            end
                        end
                    end
                end
                dictionary.characters = characters
                dictionary.unicodes   = unicodes
                setmetatableindex(characters,function(t,k) local v = k and utfbyte(k) t[k] = v return v end)
            end
            t[specification.number] = dictionary
            dictionary.instance = specification.instance -- needed for hyphenchars
        end
        t[k] = dictionary
        return dictionary
    end)

    -- Beware: left and right min doesn't mean that in a 1 mmm hsize there can be snippets
    -- with less characters than either of them! This could be an option but such a narrow
    -- hsize doesn't make sense anyway.

    -- We assume that featuresets are defined global ... local definitions (also mid paragraph)
    -- make not much sense anyway. For the moment we assume no predefined sets so we don't need
    -- to store them. Nor do we need to hash them in order to save space ... no sane user will
    -- define many of them.

    local featuresets       = hyphenators.featuresets or { }
    hyphenators.featuresets = featuresets

    storage.shared.noflanguagesfeaturesets = storage.shared.noflanguagesfeaturesets or 0

    local noffeaturesets = storage.shared.noflanguagesfeaturesets

    storage.register("languages/hyphenators/featuresets",featuresets,"languages.hyphenators.featuresets")

    ----- hash = table.sequenced(featureset,",") -- no need now

    local function register(name,featureset)
        noffeaturesets = noffeaturesets + 1
        featureset.attribute = noffeaturesets
        featuresets[noffeaturesets] = featureset  -- access by attribute
        featuresets[name] = featureset            -- access by name
        storage.shared.noflanguagesfeaturesets = noffeaturesets
        return noffeaturesets
    end

    local function makeset(...)
        -- a bit overkill, supporting variants but who cares
        local set = { }
        for i=1,select("#",...) do
            local list = select(i,...)
            local kind = type(list)
            local used = nil
            if kind == "string" then
                if list == v_all then
                    -- not ok ... now all get ignored
                    return setmetatableindex(function(t,k) local v = utfchar(k) t[k] = v return v end)
                elseif list ~= "" then
                    used = lpegmatch(p_split,list)
                    set  = set or { }
                    for i=1,#used do
                        local char = used[i]
                        set[utfbyte(char)] = char
                    end
                end
            elseif kind == "table" then
                if next(list) then
                    set = set or { }
                    for byte, char in next, list do
                        set[byte] = char == true and utfchar(byte) or char
                    end
                elseif #list > 0 then
                    set = set or { }
                    for i=1,#list do
                        local l = list[i]
                        if type(l) == "number" then
                            set[l] = utfchar(l)
                        else
                            set[utfbyte(l)] = l
                        end
                    end
                end
            end
        end
        return set
    end

    -- category pd (tex also sees --- and -- as hyphens but do we really want that

    local defaulthyphens = {
        [0x002D] = true,   -- HYPHEN-MINUS
        [0x00AD] = 0x002D, -- SOFT HYPHEN (active in ConTeXt)
     -- [0x058A] = true,   -- ARMENIAN HYPHEN
     -- [0x1400] = true,   -- CANADIAN SYLLABICS HYPHEN
     -- [0x1806] = true,   -- MONGOLIAN TODO SOFT HYPHEN
        [0x2010] = true,   -- HYPHEN
     -- [0x2011] = true,   -- NON-BREAKING HYPHEN
     -- [0x2012] = true,   -- FIGURE DASH
        [0x2013] = true,   -- EN DASH
        [0x2014] = true,   -- EM DASH
     -- [0x2015] = true,   -- HORIZONTAL BAR
     -- [0x2027] = true,   -- HYPHENATION POINT
     -- [0x2E17] = true,   -- DOUBLE OBLIQUE HYPHEN
     -- [0x2E1A] = true,   -- HYPHEN WITH DIAERESIS
     -- [0x2E3A] = true,   -- TWO-EM DASH
     -- [0x2E3B] = true,   -- THREE-EM DASH
     -- [0x2E40] = true,   -- DOUBLE HYPHEN
     -- [0x301C] = true,   -- WAVE DASH
     -- [0x3030] = true,   -- WAVY DASH
     -- [0x30A0] = true,   -- KATAKANA-HIRAGANA DOUBLE HYPHEN
     -- [0xFE31] = true,   -- PRESENTATION FORM FOR VERTICAL EM DASH
     -- [0xFE32] = true,   -- PRESENTATION FORM FOR VERTICAL EN DASH
     -- [0xFE58] = true,   -- SMALL EM DASH
     -- [0xFE63] = true,   -- SMALL HYPHEN-MINUS
     -- [0xFF0D] = true,   -- FULLWIDTH HYPHEN-MINUS
    }

    local defaultjoiners = {
        [0x200C] = true, -- nzwj
        [0x200D] = true, -- zwj
    }

    local function somehyphenchar(c)
        c = tonumber(c)
        return c ~= 0 and c or nil
    end

    local function definefeatures(name,featureset)
        local extrachars   = featureset.characters -- "[]()"
        local hyphenchars  = featureset.hyphens
        local joinerchars  = featureset.joiners
        local alternative  = featureset.alternative
        local rightwordmin = tonumber(featureset.rightwordmin)
        local charmin      = tonumber(featureset.charmin) -- luatex now also has hyphenationmin
        local leftcharmin  = tonumber(featureset.leftcharmin)
        local rightcharmin = tonumber(featureset.rightcharmin)
        local leftchar     = somehyphenchar(featureset.leftchar)
        local rightchar    = somehyphenchar(featureset.rightchar)
        local rightchars   = featureset.rightchars
local rightedge    = featureset.rightedge
local autohyphen   = v_yes -- featureset.autohyphen -- insert disc
local hyphenonly   = v_yes -- featureset.hyphenonly -- don't hyphenate around
        rightchars  = rightchars  == v_word and true           or tonumber(rightchars)
        joinerchars = joinerchars == v_yes  and defaultjoiners or joinerchars -- table
        hyphenchars = hyphenchars == v_yes  and defaulthyphens or hyphenchars -- table
        -- not yet ok: extrachars have to be ignored  so it cannot be all)
        featureset.extrachars   = makeset(joinerchars or "",extrachars or "")
        featureset.hyphenchars  = makeset(hyphenchars or "")
        featureset.alternative  = alternative or "hyphenate"
        featureset.rightwordmin = rightwordmin and rightwordmin > 0 and rightwordmin or nil
        featureset.charmin      = charmin      and charmin      > 0 and charmin      or nil
        featureset.leftcharmin  = leftcharmin  and leftcharmin  > 0 and leftcharmin  or nil
        featureset.rightcharmin = rightcharmin and rightcharmin > 0 and rightcharmin or nil
        featureset.rightchars   = rightchars
        featureset.leftchar     = leftchar
        featureset.rightchar    = rightchar
     -- featureset.strict       = rightedge  == "tex"
featureset.autohyphen   = autohyphen == v_yes
featureset.hyphenonly   = hyphenonly == v_yes
        return register(name,featureset)
    end

    local function setfeatures(n)
        if not n or n == v_reset then
            n = false
        else
            local f = featuresets[n]
            if not f and type(n) == "string" then
                local t = settings_to_array(n)
                local s = { }
                for i=1,#t do
                    local ti = t[i]
                    local fs = featuresets[ti]
                    if fs then
                        for k, v in next, fs do
                            s[k] = v
                        end
                    end
                end
                n = register(n,s)
            else
                n = f and f.attribute
            end
        end
        texsetattribute(a_hyphenation,n or unsetvalue)
    end

    traditional.definefeatures = definefeatures
    traditional.setfeatures    = setfeatures

    implement {
        name      = "definehyphenationfeatures",
        actions   = definefeatures,
        arguments = {
            "string",
            {
                { "characters" },
                { "hyphens" },
                { "joiners" },
                { "rightchars" },
                { "rightwordmin", "integer" },
                { "charmin", "integer" },
                { "leftcharmin", "integer" },
                { "rightcharmin", "integer" },
                { "leftchar", "integer" },
                { "rightchar", "integer" },
                { "alternative" },
                { "rightedge" },
            }
        }
    }

    implement {
        name      = "sethyphenationfeatures",
        actions   = setfeatures,
        arguments = "string"
    }

    implement {
        name      = "registerhyphenationpattern",
        actions   = traditional.registerpattern,
        arguments = { "string",  "string",  "boolean" }
    }

    implement {
        name      = "registerhyphenationexception",
        actions   = traditional.registerexception,
        arguments = "2 strings",
    }

    -- This is a relative large function with local variables and local functions. A previous
    -- implementation had the functions outside but this is cleaner and as efficient. The test
    -- runs 100 times over tufte.tex, knuth.tex, zapf.tex, ward.tex and darwin.tex in lower
    -- and uppercase with a 1mm hsize.
    --
    --         language=0     language>0     4 | 3 * slower
    --
    -- tex     2.34 | 1.30    2.55 | 1.45    0.21 | 0.15
    -- lua     2.42 | 1.38    3.30 | 1.84    0.88 | 0.46
    --
    -- Of course we have extra overhead (virtual Lua machine) but also we check attributes and
    -- support specific local options). The test puts the typeset text in boxes and discards
    -- it. If we also flush the runtime is 4.31|2.56 and 4.99|2.94 seconds so the relative
    -- difference is (somehow) smaller. The test has 536 pages. There is a little bit of extra
    -- overhead because we store the patterns in a different way.
    --
    -- As usual I will look for speedups. Some 0.01 seconds could be gained by sharing patterns
    -- which is not impressive but it does save some 3M memory on this test. (Some optimizations
    -- already brought the 3.30 seconds down to 3.14 but it all depends on aggressive caching.)

    -- As we kick in the hyphenator before fonts get handled, we don't look at implicit (font)
    -- kerns or ligatures.

    local starttiming = statistics.starttiming
    local stoptiming  = statistics.stoptiming

 -- local strictids = {
 --     [nodecodes.hlist]   = true,
 --     [nodecodes.vlist]   = true,
 --     [nodecodes.rule]    = true,
 --     [nodecodes.dir]     = true,
 --     [nodecodes.whatsit] = true,
 --     [nodecodes.ins]     = true,
 --     [nodecodes.adjust]  = true,
 --
 --     [nodecodes.math]    = true,
 --     [nodecodes.disc]    = true,
 --
 --     [nodecodes.accent]  = true, -- never used in context
 -- }

    -- a lot of overhead when only one char

    function traditional.hyphenate(head)

        local first           = head
        local tail            = nil
        local last            = nil
        local current         = first
        local dictionary      = nil
        local instance        = nil
        local characters      = nil
        local unicodes        = nil
        local exhyphenchar    = tex.exhyphenchar
        local extrachars      = nil
        local hyphenchars     = nil
        local language        = nil
        local lastfont        = nil
        local start           = nil
        local stop            = nil
        local word            = { } -- we reuse this table
        local size            = 0
        local leftchar        = false
        local rightchar       = false -- utfbyte("-")
        local leftexchar      = false
        local rightexchar     = false -- utfbyte("-")
        local leftmin         = 0
        local rightmin        = 0
        local charmin         = 1
        local leftcharmin     = nil
        local rightcharmin    = nil
        ----- leftwordmin     = nil
        local rightwordmin    = nil
        local rightchars      = nil
        local leftchar        = nil
        local rightchar       = nil
        local attr            = nil
        local lastwordlast    = nil
        local hyphenated      = hyphenate
        ----- strict          = nil
        local exhyphenpenalty = tex.exhyphenpenalty
        local hyphenpenalty   = tex.hyphenpenalty
        local autohyphen      = false
        local hyphenonly      = false

        -- We cannot use an 'enabled' boolean (false when no characters or extras) because we
        -- can have plugins that set a characters metatable and so) ... it doesn't save much
        -- anyway. Using (unicodes and unicodes[code]) and a nil table when no characters also
        -- doesn't save much. So there not that much to gain for languages that don't hyphenate.
        --
        -- enabled = (unicodes and (next(unicodes) or getmetatable(unicodes)))
        --        or (extrachars and next(extrachars))
        --
        -- This can be used to not add characters i.e. keep size 0 but then we need to check for
        -- attributes that change it, which costs time too. Not much to gain there.

        starttiming(traditional)

        local function insertpenalty()
            local p = new_penalty(interwordpenalty)
            setattrlist(p,last)
            if trace_visualize then
                nuts.setvisual(p,"penalty")
            end
            last = getprev(last)
            first, last = insert_after(first,last,p)
        end

        local function synchronizefeatureset(a)
            local f = a and featuresets[a]
            if f then
                hyphenated   = methods[f.alternative or "hyphenate"]
                extrachars   = f.extrachars
                hyphenchars  = f.hyphenchars
                rightwordmin = f.rightwordmin
                charmin      = f.charmin
                leftcharmin  = f.leftcharmin
                rightcharmin = f.rightcharmin
                leftchar     = f.leftchar
                rightchar    = f.rightchar
             -- strict       = f.strict and strictids
                rightchars   = f.rightchars
                autohyphen   = f.autohyphen
                hyphenonly   = f.hyphenonly
                if rightwordmin and rightwordmin > 0 and lastwordlast ~= rightwordmin then
                    -- so we can change mid paragraph but it's kind of unpredictable then
                    if not tail then
                        tail = node_tail(first)
                    end
                    last = tail
                    local inword = false
                    local count  = 0
                    while last and rightwordmin > 0 do
                        local id = getid(last)
                        if id == glyph_code then
                            count = count + 1
                            inword = true
                            if trace_visualize then
                                setcolor(last,"darkgreen")
                            end
                        elseif inword then
                            inword = false
                            rightwordmin = rightwordmin - 1
                            if rightchars == true then
                                if rightwordmin > 0 then
                                    insertpenalty()
                                end
                            elseif rightchars and count <= rightchars then
                                insertpenalty()
                            end
                        end
                        last = getprev(last)
                    end
                    lastwordlast = rightwordmin
                end
                if not charmin or charmin == 0 then
                    charmin = 1
                end
            else
                hyphenated   = methods.hyphenate
                extrachars   = false
                hyphenchars  = false
                rightwordmin = false
                charmin      = 1
                leftcharmin  = false
                rightcharmin = false
                leftchar     = false
                rightchar    = false
             -- strict       = false
                autohyphen   = false
                hyphenonly   = false
            end

            return a
        end

        local function flush(hyphens) -- todo: no need for result

            local rightmin = size - rightmin
            local result   = { }
            local rsize    = 0
            local position = 1

            -- todo: remember last dics and don't go back to before that (plus message) ...
            -- for simplicity we also assume that we don't start with a dics node
            --
            -- there can be a conflict: if we backtrack then we can end up in another disc
            -- and get out of sync (dup chars and so)

            while position <= size do
                if position >= leftmin and position <= rightmin then
                    local hyphen = hyphens[position]
                    if not hyphen then
                        rsize = rsize + 1
                        result[rsize] = word[position]
                        position = position + 1
                    elseif hyphen == true then
                        rsize = rsize + 1
                        result[rsize] = word[position]
                        rsize = rsize + 1
                        result[rsize] = true
                        position = position + 1
                    else
                        local o, h = hyphen[2]
                        if o then
                            -- { hyphen, offset)
                            h = hyphen[1]
                        else
                            -- hyphen
                            h = hyphen
                            o = 1
                        end
                        local b = position - o + (h.start  or 1)
                        local e = b + (h.length or 2) - 1
                        if b > 0 and e >= b then
                            for i=1,b-position do
                                rsize = rsize + 1
                                result[rsize] = word[position]
                                position = position + 1
                            end
                            rsize = rsize + 1
                            result[rsize] = {
                                h.before or "",      -- pre
                                h.after or "",       -- post
                                concat(word,"",b,e), -- replace
                                h.right,             -- optional after pre
                                h.left,              -- optional before post
                            }
                            position = e + 1
                        else
                            -- error
                            rsize = rsize + 1
                            result[rsize] = word[position]
                            position = position + 1
                        end
                    end
                else
                    rsize = rsize + 1
                    result[rsize] = word[position]
                    position = position + 1
                end
            end

            local function serialize(replacement,leftchar,rightchar)
                if not replacement then
                    return
                elseif replacement == true then
                    local glyph = copy_node(stop)
                    setchar(glyph,leftchar or rightchar)
                    return glyph
                end
                local head    = nil
                local current = nil
                if leftchar then
                    head    = copy_node(stop)
                    current = head
                    setchar(head,leftchar)
                end
                local rsize = #replacement
                if rsize == 1 then
                    local glyph = copy_node(stop)
                    setchar(glyph,characters[replacement])
                    if head then
                        insert_after(current,current,glyph)
                    else
                        head = glyph
                    end
                    current = glyph
                elseif rsize > 0 then
                    local list = lpegmatch(p_split,replacement) -- this is an utf split (could be cached)
                    for i=1,#list do
                        local glyph = copy_node(stop)
                        setchar(glyph,characters[list[i]])
                        if head then
                            insert_after(current,current,glyph)
                        else
                            head = glyph
                        end
                        current = glyph
                    end
                end
                if rightchar then
                    local glyph = copy_node(stop)
                    insert_after(current,current,glyph)
                    setchar(glyph,rightchar)
                end
                return head
            end

            local current  = start
            local attrnode = start -- will be different, just the first char

            for i=1,rsize do
                local r = result[i]
                if r == true then
                    local disc = new_disc()
                    local pre  = nil
                    local post = nil
                    if rightchar then
                        pre = serialize(true,rightchar)
                    end
                    if leftchar then
                        post = serialize(true,leftchar)
                    end
                    setdisc(disc,pre,post,nil,regulardisc_code,hyphenpenalty)
                    if attrnode then
                        setattrlist(disc,attrnode)
                    end
                    -- could be a replace as well
                    insert_before(first,current,disc)
                elseif type(r) == "table" then
                    local disc    = new_disc()
                    local pre     = r[1]
                    local post    = r[2]
                    local replace = r[3]
                    local right   = r[4] ~= false and rightchar
                    local left    = r[5] ~= false and leftchar
                    if pre then
                        if pre ~= "" then
                            pre = serialize(pre,false,right)
                        else
                            pre = nil
                        end
                    end
                    if post then
                        if post ~= "" then
                            post = serialize(post,left,false)
                        else
                            post = nil
                        end
                    end
                    if replace then
                        if replace ~= "" then
                            replace = serialize(replace)
                        else
                            replace = nil
                        end
                    end
                    -- maybe regular code
                    setdisc(disc,pre,post,replace,regulardisc_code,hyphenpenalty)
                    if attrnode then
                        setattrlist(disc,attrnode)
                    end
                    insert_before(first,current,disc)
                else
                    setchar(current,characters[r])
                    if i < rsize then
                        current = getnext(current)
                    end
                end
            end
            if current and current ~= stop then
                local current = getnext(current)
                local last    = getnext(stop)
                while current ~= last do
                    first, current = remove_node(first,current,true)
                end
            end

        end

        local function inject(leftchar,rightchar,code,attrnode)
            if first ~= current then
                local disc = new_disc()
                first, current, glyph = remove_node(first,current)
                first, current = insert_before(first,current,disc)
                if trace_visualize then
                    setcolor(glyph,"darkred")  -- these get checked
                    setcolor(disc,"darkgreen") -- in the colorizer
                end
                local pre     = nil
                local post    = nil
                local replace = glyph
                if leftchar and leftchar > 0 then
                    post = copy_node(glyph)
                    setchar(post,leftchar)
                end
                pre = copy_node(glyph)
                setchar(pre,rightchar and rightchar > 0 and rightchar or code)
                setdisc(disc,pre,post,replace,automaticdisc_code,hyphenpenalty) -- ex ?
                if attrnode then
                    setattrlist(disc,attrnode)
                end
            end
            return current
        end

        local function injectseries(current,last,next,attrnode)
            local disc  = new_disc()
            local start = current
            first, current = insert_before(first,current,disc)
            setprev(start)
            setnext(last)
            if next then
                setlink(current,next)
            else
                setnext(current)
            end
            local pre     = copy_list(start)
            local post    = nil
            local replace = start
            setdisc(disc,pre,post,replace,automaticdisc_code,hyphenpenalty) -- ex ?
            if attrnode then
                setattrlist(disc,attrnode)
            end
            return current
        end

        local a = getattr(first,a_hyphenation)
        if a ~= attr then
            attr = synchronizefeatureset(a)
        end

        -- The first attribute in a word determines the way a word gets hyphenated and if
        -- relevant, other properties are also set then. We could optimize for silly one-char
        -- cases but it has no priority as the code is still not that much slower than the
        -- native hyphenator and this variant also provides room for extensions.

        local skipping = false

        -- In "word word word." the sequences "word" and "." can be a different font!

        while current and current ~= last do -- and current
            local code, id = isglyph(current)
            if code then
                if skipping then
                    current = getnext(current)
                else
                    local lang = getlang(current)
                    local font = getfont(current)
                    if lang ~= language or font ~= lastfont then
                        if dictionary and size > charmin and leftmin + rightmin <= size then
                            -- only german has many words starting with an uppercase character
                            if categories[word[1]] == "lu" and getfield(start,"uchyph") < 0 then
                                -- skip
                            else
                                local hyphens = hyphenated(dictionary,word,size)
                                if hyphens then
                                    flush(hyphens)
                                end
                            end
                        end
                        lastfont = font
                        if language ~= lang and lang > 0 then
                            --
                            dictionary = dictionaries[lang]
                            instance   = dictionary.instance
                            characters = dictionary.characters
                            unicodes   = dictionary.unicodes
                            --
                            local a = getattr(current,a_hyphenation)
                            attr        = synchronizefeatureset(a)
                            leftchar    = leftchar     or (instance and posthyphenchar  (instance)) -- we can make this more
                            rightchar   = rightchar    or (instance and prehyphenchar   (instance)) -- efficient if needed
                            leftexchar  =                 (instance and preexhyphenchar (instance))
                            rightexchar =                 (instance and postexhyphenchar(instance))
                            leftmin     = leftcharmin  or getfield(current,"left")
                            rightmin    = rightcharmin or getfield(current,"right")
                            if not leftchar or leftchar < 0 then
                                leftchar = false
                            end
                            if not rightchar or rightchar < 0 then
                                rightchar = false
                            end
                            --
                            local char = unicodes[code] or (extrachars and extrachars[code])
                            if char then
                                word[1] = char
                                size    = 1
                                start   = current
                            else
                                size = 0
                            end
                        else
                            size = 0
                        end
                        language = lang
                    elseif language <= 0 then
                        --
                    elseif size > 0 then
                        local char = unicodes[code] or (extrachars and extrachars[code])
                        if char then
                            size = size + 1
                            word[size] = char
                        elseif dictionary then
                            if not hyphenonly or code ~= exhyphenchar then
                                if size > charmin and leftmin + rightmin <= size then
                                    if categories[word[1]] == "lu" and getfield(start,"uchyph") < 0 then
                                        -- skip
                                    else
                                        local hyphens = hyphenated(dictionary,word,size)
                                        if hyphens then
                                            flush(hyphens)
                                        end
                                    end
                                end
                            end
                            size = 0
                            if code == exhyphenchar then -- normally the -
                                local next = getnext(current)
                                local last = current
                                local font = getfont(current)
                                while next and ischar(next,font) == code do
                                    last = next
                                    next = getnext(next)
                                end
                                if not autohyphen then
                                    current = last
                                elseif current == last then
                                    current = inject(leftexchar,rightexchar,code,current)
                                else
                                    current = injectseries(current,last,next,current)
                                end
                                if hyphenonly then
                                    skipping = true
                                end
                            elseif hyphenchars then
                                local char = hyphenchars[code]
                                if char == true then
                                    char = code
                                end
                                if char then
                                    current = inject(leftchar and char or nil,rightchar and char or nil,char,current)
                                end
                            end
                        end
                    else
                        local a = getattr(current,a_hyphenation)
                        if a ~= attr then
                            attr        = synchronizefeatureset(a) -- influences extrachars
                            leftchar    = leftchar     or (instance and posthyphenchar  (instance)) -- we can make this more
                            rightchar   = rightchar    or (instance and prehyphenchar   (instance)) -- efficient if needed
                            leftexchar  =                 (instance and preexhyphenchar (instance))
                            rightexchar =                 (instance and postexhyphenchar(instance))
                            leftmin     = leftcharmin  or getfield(current,"left")
                            rightmin    = rightcharmin or getfield(current,"right")
                            if not leftchar or leftchar < 0 then
                                leftchar = false
                            end
                            if not rightchar or rightchar < 0 then
                                rightchar = false
                            end
                        end
                        --
                        local char = unicodes[code] or (extrachars and extrachars[code])
                        if char then
                            word[1] = char
                            size    = 1
                            start   = current
                        end
                    end
                    stop    = current
                    current = getnext(current)
                end
            else
                if skipping then
                    skipping = false
                end
                if id == disc_code then
                    size = 0
                    current = getnext(current)
                    if hyphenonly then
                        skipping = true
                    end
             -- elseif strict and strict[id] then
             --     current = id == math_code and getnext(end_of_math(current)) or getnext(current)
             --     size = 0
                else
                    current = id == math_code and getnext(end_of_math(current)) or getnext(current)
                end
                if size > 0 then
                    if dictionary and size > charmin and leftmin + rightmin <= size then
                        if categories[word[1]] == "lu" and getfield(start,"uchyph") < 0 then
                            -- skip
                        else
                            local hyphens = hyphenated(dictionary,word,size)
                            if hyphens then
                                flush(hyphens)
                            end
                        end
                    end
                    size = 0
                end
            end
        end
        -- we can have quit due to last so we need to flush the last seen word, we could move
        -- this in the loop and test for current but ... messy
        if dictionary and size > charmin and leftmin + rightmin <= size then
            if categories[word[1]] == "lu" and getfield(start,"uchyph") < 0 then
                -- skip
            else
                local hyphens = hyphenated(dictionary,word,size)
                if hyphens then
                    flush(hyphens)
                end
            end
        end

        stoptiming(traditional)

        return head
    end

    statistics.register("hyphenation",function()
        if nofwords > 0 or statistics.elapsed(traditional) > 0 then
            return string.format("%s words hyphenated, %s unique, used time %s",
                nofwords,nofhashed,statistics.elapsedseconds(traditional) or 0)
        end
    end)

    local texmethod = "builders.kernel.hyphenation"
    local oldmethod = texmethod
    local newmethod = texmethod

 -- local newmethod = "languages.hyphenators.traditional.hyphenate"
 --
 -- nodes.tasks.prependaction("processors","words",newmethod)
 -- nodes.tasks.disableaction("processors",oldmethod)
 --
 -- nodes.tasks.replaceaction("processors","words",oldmethod,newmethod)

 -- \enabledirectives[hyphenators.method=traditional]
 -- \enabledirectives[hyphenators.method=builtin]

    -- push / pop ? check first attribute

    -- local replaceaction = nodes.tasks.replaceaction -- no longer overload this way (too many local switches)

    local hyphenate    = lang.hyphenate
    local hyphenating  = nuts.hyphenating
    local methods      = { }
    local usedmethod   = false
    local stack        = { }

    local original = hyphenating and
        function(head)
            return (hyphenating(head))
        end
    or
        function(head)
            hyphenate(tonode(head))
            return head -- a nut
        end

 -- local has_language = lang.has_language
 --
 -- local function original(head) -- kernel.hyphenation(head)
 --     local h = tonode(head)
 --     if has_language(h) then
 --         hyphenate(h)
 --     end
 --     return head
 -- end

    local getcount = tex.getcount

    hyphenators.methods  = methods
    local optimize       = false

    directives.register("hyphenator.optimize", function(v) optimize = v end)

    function hyphenators.handler(head,groupcode)
        if usedmethod then
            if optimize and (groupcode == "hbox" or groupcode == "adjusted_hbox") then
                if getcount("hyphenstate") > 0 then
                    forced = false
                    return usedmethod(head)
                else
                    return head
                end
            else
                return usedmethod(head)
            end
        else
            return head
        end
    end

    methods.tex         = original
    methods.original    = original
    methods.expanded    = original -- was expanded before 1.005
    methods.traditional = languages.hyphenators.traditional.hyphenate
    methods.none        = false -- function(head) return head, false end

    usedmethod          = original

    local function setmethod(method)
        usedmethod = type(method) == "string" and methods[method]
        if usedmethod == nil then
            usedmethod = methods.tex
        end
    end
    local function pushmethod(method)
        insert(stack,usedmethod)
        usedmethod = type(method) == "string" and methods[method]
        if usedmethod == nil then
            usedmethod = methods.tex
        end
    end
    local function popmethod()
        usedmethod = remove(stack) or methods.tex
    end

    hyphenators.setmethod  = setmethod
    hyphenators.pushmethod = pushmethod
    hyphenators.popmethod  = popmethod

    directives.register("hyphenators.method",setmethod)

    function hyphenators.setup(specification)
        local method = specification.method
        if method then
            setmethod(method)
        end
    end

    implement { name = "sethyphenationmethod", actions = setmethod,  arguments = "string" }
    implement { name = "pushhyphenation",      actions = pushmethod, arguments = "string" }
    implement { name = "pophyphenation",       actions = popmethod }

    -- can become a runtime loaded one:

    local context      = context
    local ctx_NC       = context.NC
    local ctx_NR       = context.NR
    local ctx_verbatim = context.verbatim

    function hyphenators.showhyphenationtrace(language,word)
        if not word or word == "" then
            return
        end
        local saved = trace_steps
        trace_steps = "silent"
        local steps = traditional.gettrace(language,word)
        trace_steps = saved
        if steps then
            local n = #steps
            if n > 0 then
                context.starttabulate { "|r|l|l|l|" }
                for i=1,n do
                    local s = steps[i]
                    ctx_NC() if i > 1 and i < n then context(i-1) end
                    ctx_NC() ctx_verbatim(s[1])
                    ctx_NC() ctx_verbatim(s[2])
                    ctx_NC() ctx_verbatim(s[3])
                    ctx_NC()
                    ctx_NR()
                end
                context.stoptabulate()
            end
        end
    end

    implement {
        name      = "showhyphenationtrace",
        actions   = hyphenators.showhyphenationtrace,
        arguments = "2 strings",
    }

    function nodes.stripdiscretionaries(head)
        for l in nexthlist, head do
            for d in nextdisc, getlist(l) do
                remove_node(h,false,true)
            end
        end
        return head
    end


else

    -- traditional.loadpatterns("nl","lang-nl")
    -- traditional.loadpatterns("de","lang-de")
    -- traditional.loadpatterns("us","lang-us")

    -- traditional.registerpattern("nl","e1ë",      { start = 1, length = 2, before = "e",  after = "e"  } )
    -- traditional.registerpattern("nl","oo7ë",     { start = 2, length = 3, before = "o",  after = "e"  } )
    -- traditional.registerpattern("de","qqxc9xkqq",{ start = 3, length = 4, before = "ab", after = "cd" } )

    -- local specification = {
    --     leftcharmin     = 2,
    --     rightcharmin    = 2,
    --     leftchar        = "<",
    --     rightchar       = ">",
    -- }

    -- print("reëel",       traditional.injecthyphens(dictionaries.nl,"reëel",       specification),"r{e>}{<e}{eë}el")
    -- print("reeëel",      traditional.injecthyphens(dictionaries.nl,"reeëel",      specification),"re{e>}{<e}{eë}el")
    -- print("rooëel",      traditional.injecthyphens(dictionaries.nl,"rooëel",      specification),"r{o>}{<e}{ooë}el")

    -- print(   "qxcxkq",   traditional.injecthyphens(dictionaries.de,   "qxcxkq",   specification),"")
    -- print(  "qqxcxkqq",  traditional.injecthyphens(dictionaries.de,  "qqxcxkqq",  specification),"")
    -- print( "qqqxcxkqqq", traditional.injecthyphens(dictionaries.de, "qqqxcxkqqq", specification),"")
    -- print("qqqqxcxkqqqq",traditional.injecthyphens(dictionaries.de,"qqqqxcxkqqqq",specification),"")

    -- print("kunstmatig",       traditional.injecthyphens(dictionaries.nl,"kunstmatig",       specification),"")
    -- print("kunststofmatig",   traditional.injecthyphens(dictionaries.nl,"kunststofmatig",   specification),"")
    -- print("kunst[stof]matig", traditional.injecthyphens(dictionaries.nl,"kunst[stof]matig", specification),"")

    -- traditional.loadpatterns("us","lang-us")

    -- local specification = {
    --     leftcharmin     = 2,
    --     rightcharmin    = 2,
    --     leftchar        = false,
    --     rightchar       = false,
    -- }

    -- trace_steps = true

    -- print("components",    traditional.injecthyphens(dictionaries.us,"components", specification),"")
    -- print("single",        traditional.injecthyphens(dictionaries.us,"single",     specification),"sin-gle")
    -- print("everyday",      traditional.injecthyphens(dictionaries.us,"everyday",   specification),"every-day")
    -- print("associate",     traditional.injecthyphens(dictionaries.us,"associate",     specification),"as-so-ciate")
    -- print("philanthropic", traditional.injecthyphens(dictionaries.us,"philanthropic", specification),"phil-an-thropic")
    -- print("projects",      traditional.injecthyphens(dictionaries.us,"projects",      specification),"projects")
    -- print("Associate",     traditional.injecthyphens(dictionaries.us,"Associate",     specification),"As-so-ciate")
    -- print("Philanthropic", traditional.injecthyphens(dictionaries.us,"Philanthropic", specification),"Phil-an-thropic")
    -- print("Projects",      traditional.injecthyphens(dictionaries.us,"Projects",      specification),"Projects")

end

