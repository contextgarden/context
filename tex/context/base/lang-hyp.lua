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
-- the most critital code.
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

local type, rawset, tonumber = type, rawset, tonumber

local P, R, S, Cg, Cf, Ct, Cc, C, Carg, Cs = lpeg.P, lpeg.R, lpeg.S, lpeg.Cg, lpeg.Cf, lpeg.Ct, lpeg.Cc, lpeg.C, lpeg.Carg, lpeg.Cs
local lpegmatch = lpeg.match

local concat = table.concat

local utfchar = utf.char
local utfbyte = utf.byte

if not characters then
    require("char-ini")
end

local setmetatableindex = table.setmetatableindex

local languages         = languages or { }
local hyphenators       = languages.hyphenators or { }
languages.hyphenators   = hyphenators
local traditional       = hyphenators.traditional or { }
hyphenators.traditional = traditional

local dictionaries = setmetatableindex(function(t,k)
    local v = {
        patterns   = { },
        hyphenated = { },
        specials   = { },
    }
    t[k] = v
    return v
end)

local digit          = R("09")
local character      = lpeg.patterns.utf8character - P("/")
local splitpattern_k = Cs((digit/"" + character)^1)
local splitpattern_v = Ct(((digit/tonumber + Cc(0)) * character)^1 * (digit/tonumber)^0)
local splitpattern_v =
    Ct(((digit/tonumber + Cc(0)) * character)^1 * (digit/tonumber)^0) *
    (P("/") * Cf ( Ct("") *
        Cg ( Cc("before") * C((1-lpeg.P("="))^1)          * P("=") )
      * Cg ( Cc("after")  * C((1-lpeg.P(","))^1)          * P(",") )
      * Cg ( Cc("start")  * ((1-lpeg.P(","))^1/tonumber)  * P(",") )
      * Cg ( Cc("length") * ((1-lpeg.P(-1) )^1/tonumber)           )
    , rawset))^-1

local function register(patterns,specials,str,specification)
    local k = lpegmatch(splitpattern_k,str)
    local v1, v2 = lpegmatch(splitpattern_v,str)
    patterns[k] = v1
    if specification then
        specials[k] = specification
    elseif v2 then
        specials[k] = v2
    end
end

local word  = ((Carg(1) * Carg(2) * C((1 - P(" "))^1)) / register + 1)^1
local split = Ct(C(character)^1)

function traditional.loadpatterns(language,filename)
    local specification = require(filename)
    local dictionary    = dictionaries[language]
    if specification then
        local patterns = specification.patterns
        if patterns then
            lpegmatch(word,patterns.data,1,dictionary.patterns,dictionary.specials)
        end
    end
    return dictionary
end

local lcchars   = characters.lcchars
local uccodes   = characters.uccodes
local nofwords  = 0
local nofhashed = 0

local function hyphenate(dictionary,word)
    nofwords = nofwords + 1
    local hyphenated = dictionary.hyphenated
    local isstring   = type(word) == "string"
    local done
    if isstring then
        done = hyphenated[word]
    else
        done = hyphenated[concat(word)]
    end
    if done ~= nil then
        return done
    else
        done = false
    end
    local specials = dictionary.specials
    local patterns = dictionary.patterns
    local s = isstring and lpegmatch(split,word) or word
    local l = #s
    local w = { }
    for i=1,l do
        local si = s[i]
        w[i] = lcchars[si] or si
    end
    local spec
    for i=1,l do
        for j=i,l do
            local c = concat(w,"",i,j)
            local m = patterns[c]
            if m then
                local s = specials[c]
                if not done then
                    done = { }
                    spec = { }
                    for i=1,l do
                        done[i] = 0
                    end
                end
                for k=1,#m do
                    local new = m[k]
                    if not new then
                        break
                    elseif new > 0 then
                        local pos = i + k - 1
                        local old = done[pos]
                        if not old then
                            -- break ?
                        elseif new > old then
                            done[pos] = new
                            if s then
                                local b = i + s.start - 1
                                local e = b + s.length - 1
                                if pos >= b and pos <= e then
                                    spec[pos] = s
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    if done then
        local okay = false
        for i=1,#done do
            if done[i] % 2 == 1 then
                done[i] = spec[i] or true
                okay = true
            else
                done[i] = false
            end
        end
        if not okay then
            done = false
        end
    end
    hyphenated[isstring and word or concat(word)] = done
    nofhashed = nofhashed + 1
    return done
end

local f_detail_1 = string.formatters["{%s}{%s}{}"]
local f_detail_2 = string.formatters["{%s%s}{%s%s}{%s}"]

function traditional.injecthyphens(dictionary,word,specification)
    local h = hyphenate(dictionary,word)
    if not h then
        return word
    end
    local w = lpegmatch(split,word)
    local r = { }
    local l = #h
    local n = 0
    local i = 1
    local leftmin   = specification.lefthyphenmin or 2
    local rightmin  = l - (specification.righthyphenmin or left) + 1
    local leftchar  = specification.lefthyphenchar
    local rightchar = specification.righthyphenchar
    while i <= l do
        if i > leftmin and i < rightmin then
            local hi = h[i]
            if not hi then
                n = n + 1
                r[n] = w[i]
                i = i + 1
            elseif hi == true then
                n = n + 1
                r[n] = f_detail_1(rightchar,leftchar)
                n = n + 1
                r[n] = w[i]
                i = i + 1
            else
                local b = i - hi.start
                local e = b + hi.length - 1
                n = b
                r[n] = f_detail_2(hi.before,rightchar,leftchar,hi.after,concat(w,"",b,e))
                if e + 1 == i then
                    i = i + 1
                else
                    i = e + 1
                end
            end
        else
            n = n + 1
            r[n] = w[i]
            i = i + 1
        end
    end
    return concat(r)
end

function traditional.registerpattern(language,str,specification)
    local dictionary = dictionaries[language]
    register(dictionary.patterns,dictionary.specials,str,specification)
end

-- todo: unicodes or utfhash ?

if context then

    local nodecodes     = nodes.nodecodes
    local glyph_code    = nodecodes.glyph
    local math_code     = nodecodes.math

    local nuts          = nodes.nuts
    local tonut         = nodes.tonut
    local nodepool      = nuts.pool

    local new_disc      = nodepool.disc

    local setfield      = nuts.setfield
    local getfield      = nuts.getfield
    local getchar       = nuts.getchar
    local getid         = nuts.getid
    local getnext       = nuts.getnext
    local getprev       = nuts.getprev
    local insert_before = nuts.insert_before
    local insert_after  = nuts.insert_after
    local copy_node     = nuts.copy
    local remove_node   = nuts.remove
    local end_of_math   = nuts.end_of_math
    local node_tail     = nuts.tail

    function traditional.loadpatterns(language)
        return dictionaries[language]
    end

    statistics.register("hyphenation",function()
        if nofwords > 0 then
            return string.format("%s words hyphenated, %s unique",nofwords,nofhashed)
        end
    end)

    setmetatableindex(dictionaries,function(t,k) -- we use an independent data structure
        local specification = languages.getdata(k)
        local dictionary    = {
            patterns   = { },
            hyphenated = { },
            specials   = { },
            instance   = 0,
            characters = { },
            unicodes   = { },
        }
        if specification then
            local resources = specification.resources
            if resources then
                local patterns = resources.patterns
                if patterns then
                    local data = patterns.data
                    if data then
                        -- regular patterns
                        lpegmatch(word,data,1,dictionary.patterns,dictionary.specials)
                    end
                    local extra = patterns.extra
                    if extra then
                        -- special patterns
                        lpegmatch(word,extra,1,dictionary.patterns,dictionary.specials)
                    end
                end
                local usedchars  = lpegmatch(split,patterns.characters)
                local characters = { }
                local unicodes   = { }
                for i=1,#usedchars do
                    local char  = usedchars[i]
                    local code  = utfbyte(char)
                    local upper = uccodes[code]
                    characters[char]  = code
                    unicodes  [code]  = char
                    unicodes  [upper] = utfchar(upper)
                end
                dictionary.characters = characters
                dictionary.unicodes   = unicodes
                setmetatableindex(characters,function(t,k) local v = utfbyte(k) t[k] = v return v end) -- can be non standard
             -- setmetatableindex(unicodes,  function(t,k) local v = utfchar(k) t[k] = v return v end)
            end
            t[specification.number] = dictionary
            dictionary.instance = specification.instance -- needed for hyphenchars
        end
        t[k] = dictionary
        return dictionary
    end)

    local function flush(head,start,stop,dictionary,w,h,lefthyphenchar,righthyphenchar,characters,lefthyphenmin,righthyphenmin)
        local r = { }
        local l = #h
        local n = 0
        local i = 1
        local left  = lefthyphenmin
        local right = l - righthyphenmin + 1
        while i <= l do
            if i > left and i < right then
                local hi = h[i]
                if not hi then
                    n = n + 1
                    r[n] = w[i]
                    i = i + 1
                elseif hi == true then
                    n = n + 1
                    r[n] = true
                    n = n + 1
                    r[n] = w[i]
                    i = i + 1
                else
                    local b = i - hi.start  -- + 1 - 1
                    local e = b + hi.length - 1
                    n = b
                    r[n] = { hi.before, hi.after, concat(w,"",b,e) }
                    i = e + 1
                end
            else
                n = n + 1
                r[n] = w[i]
                i = i + 1
            end
        end

        local function serialize(s,lefthyphenchar,righthyphenchar)
            if not s then
                return
            elseif s == true then
                local n = copy_node(stop)
                setfield(n,"char",lefthyphenchar or righthyphenchar)
                return n
            end
            local h = nil
            local c = nil
            if lefthyphenchar then
                h = copy_node(stop)
                setfield(h,"char",lefthyphenchar)
                c = h
            end
            if #s == 1 then
                local n = copy_node(stop)
                setfield(n,"char",characters[s])
                if not h then
                    h = n
                else
                    insert_after(c,c,n)
                end
                c = n
            else
                local t = lpegmatch(split,s)
                for i=1,#t do
                    local n = copy_node(stop)
                    setfield(n,"char",characters[t[i]])
                    if not h then
                        h = n
                    else
                        insert_after(c,c,n)
                    end
                    c = n
                end
            end
            if righthyphenchar then
                local n = copy_node(stop)
                insert_after(c,c,n)
                setfield(n,"char",righthyphenchar)
            end
            return h
        end

        -- no grow

        local current = start
        local size    = #r
        for i=1,size do
            local ri = r[i]
            if ri == true then
                local n = new_disc()
                if righthyphenchar then
                    setfield(n,"pre",serialize(true,righthyphenchar))
                end
                if lefthyphenchar then
                    setfield(n,"post",serialize(true,lefthyphenchar))
                end
                insert_before(head,current,n)
            elseif type(ri) == "table" then
                local n = new_disc()
                local pre, post, replace = ri[1], ri[2], ri[3]
                if pre then
                    setfield(n,"pre",serialize(pre,false,righthyphenchar))
                end
                if post then
                    setfield(n,"post",serialize(post,lefthyphenchar,false))
                end
                if replace then
                    setfield(n,"replace",serialize(replace))
                end
                insert_before(head,current,n)
            else
                setfield(current,"char",characters[ri])
                if i < size then
                    current = getnext(current)
                end
            end
        end
        if current ~= stop then
            local current = getnext(current)
            local last = getnext(stop)
            while current ~= last do
                head, current = remove_node(head,current,true)
            end
        end
    end

    -- simple cases: no special .. only inject

    local prehyphenchar  = lang.prehyphenchar
    local posthyphenchar = lang.posthyphenchar

    local lccodes        = characters.lccodes

    -- An experimental feature:
    --
    -- \setupalign[verytolerant,flushleft]
    -- \setuplayout[width=140pt] \showframe
    -- longword longword long word longword longwordword \par
    -- \enabledirectives[hyphenators.rightwordsmin=1]
    -- longword longword long word longword longwordword \par
    -- \disabledirectives[hyphenators.rightwordsmin]
    --
    -- An alternative is of course to pack the words in an hbox.

    local rightwordsmin = 0 -- todo: parproperties (each par has a number anyway)

    function traditional.hyphenate(head)
        local first      = tonut(head)
        local current    = first
        local dictionary = nil
        local instance   = nil
        local characters = nil
        local unicodes   = nil
        local language   = nil
        local start      = nil
        local stop       = nil
        local word       = nil -- maybe reuse and pass size
        local size       = 0
        local leftchar   = false
        local rightchar  = false -- utfbyte("-")
        local leftmin    = 0
        local rightmin   = 0
        local lastone    = nil

        if rightwordsmin > 0 then
            lastone = node_tail(first)
            local inword = false
            while lastone and rightwordsmin > 0 do
                local id = getid(lastone)
                if id == glyph_code then
                    inword = true
                elseif inword then
                    inword = false
                    rightwordsmin = rightwordsmin - 1
                end
                lastone = getprev(lastone)
            end
        end

        while current ~= lastone do
            local id = getid(current)
            if id == glyph_code then
                -- currently no lc/uc code support
                local code = getchar(current)
                local lang = getfield(current,"lang")
                if lang ~= language then
                    if dictionary then
                        if leftmin + rightmin < #word then
                            local done = hyphenate(dictionary,word)
                            if done then
                                flush(first,start,stop,dictionary,word,done,leftchar,rightchar,characters,leftmin,rightmin)
                            end
                        end
                    end
                    language   = lang
                    dictionary = dictionaries[language]
                    instance   = dictionary.instance
                    characters = dictionary.characters
                    unicodes   = dictionary.unicodes
                    leftchar   = instance and posthyphenchar(instance)
                    rightchar  = instance and prehyphenchar (instance)
                    leftmin    = getfield(current,"left")
                    rightmin   = getfield(current,"right")
                    if not leftchar or leftchar < 0 then
                        leftchar = false
                    end
                    if not rightchar or rightchar < 0 then
                        rightchar = false
                    end
                    local char = unicodes[code]
                    if char then
                        word  = { char }
                        size  = 1
                        start = current
                    end
                elseif word then
                    local char = unicodes[code]
                    if char then
                        size = size + 1
                        word[size] = char
                    elseif dictionary then
                        if leftmin + rightmin < #word then
                            local done = hyphenate(dictionary,word)
                            if done then
                                flush(first,start,stop,dictionary,word,done,leftchar,rightchar,characters,leftmin,rightmin)
                            end
                        end
                        word = nil
                    end
                else
                    local char = unicodes[code]
                    if char then
                        word     = { char }
                        size     = 1
                        start    = current
                     -- leftmin  = getfield(current,"left")  -- can be an option
                     -- rightmin = getfield(current,"right") -- can be an option
                    end
                end
                stop    = current
                current = getnext(current)
            elseif word then
                if dictionary then
                    if leftmin + rightmin < #word then
                        local done = hyphenate(dictionary,word)
                        current = getnext(current)
                        if done then
                            flush(first,start,stop,dictionary,word,done,leftchar,rightchar,characters,leftmin,rightmin)
                        end
                    else
                        current = getnext(current) -- hm
                    end
                else
                    current = getnext(current)
                end
                word = nil
            elseif id == math_code then
                current = getnext(end_of_math(current))
            else
                current = getnext(current)
            end
        end
        return head, true
    end

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

    directives.register("hyphenators.method",function(v)
        if type(v) == "string" then
            local valid = languages.hyphenators[v]
            if valid and valid.hyphenate then
                newmethod = "languages.hyphenators." .. v .. ".hyphenate"
            else
                newmethod = texmethod
            end
        else
            newmethod = texmethod
        end
        if oldmethod ~= newmethod then
            nodes.tasks.replaceaction("processors","words",oldmethod,newmethod)
        end
        oldmethod = newmethod
    end)

    -- experimental feature

    directives.register("hyphenators.rightwordsmin",function(v)
        rightwordsmin = tonumber(v) or 0
    end)

else

 -- traditional.loadpatterns("nl","lang-nl")
 -- traditional.loadpatterns("de","lang-de")

    traditional.registerpattern("nl","e1ë",      { start = 1, length = 2, before = "e",  after = "e"  } )
    traditional.registerpattern("nl","oo1ë",     { start = 2, length = 3, before = "o",  after = "e"  } )
    traditional.registerpattern("de","qqxc9xkqq",{ start = 3, length = 4, before = "ab", after = "cd" } )

    local specification = {
        lefthyphenmin   = 2,
        righthyphenmin  = 2,
        lefthyphenchar  = "<",
        righthyphenchar = ">",
    }

    print("reëel",       traditional.injecthyphens(dictionaries.nl,"reëel",       specification),"r{e>}{<e}{eë}el")
    print("reeëel",      traditional.injecthyphens(dictionaries.nl,"reeëel",      specification),"re{e>}{<e}{eë}el")
    print("rooëel",      traditional.injecthyphens(dictionaries.nl,"rooëel",      specification),"r{o>}{<e}{ooë}el")

    print(   "qxcxkq",   traditional.injecthyphens(dictionaries.de,   "qxcxkq",   specification),"")
    print(  "qqxcxkqq",  traditional.injecthyphens(dictionaries.de,  "qqxcxkqq",  specification),"")
    print( "qqqxcxkqqq", traditional.injecthyphens(dictionaries.de, "qqqxcxkqqq", specification),"")
    print("qqqqxcxkqqqq",traditional.injecthyphens(dictionaries.de,"qqqqxcxkqqqq",specification),"")

end

