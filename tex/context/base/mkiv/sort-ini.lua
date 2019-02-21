if not modules then modules = { } end modules ['sort-ini'] = {
    version   = 1.001,
    comment   = "companion to sort-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- It took a while to get there, but with Fleetwood Mac's "Don't Stop"
-- playing in the background we sort of got it done.

--[[<p>The code here evolved from the rather old mkii approach. There
we concatinate the key and (raw) entry into a new string. Numbers and
special characters get some treatment so that they sort ok. In
addition some normalization (lowercasing, accent stripping) takes
place and again data is appended ror prepended. Eventually these
strings are sorted using a regular string sorter. The relative order
of character is dealt with by weighting them. It took a while to
figure this all out but eventually it worked ok for most languages,
given that the right datatables were provided.</p>

<p>Here we do follow a similar approach but this time we don't append
the manipulated keys and entries but create tables for each of them
with entries being tables themselves having different properties. In
these tables characters are represented by numbers and sorting takes
place using these numbers. Strings are simplified using lowercasing
as well as shape codes. Numbers are filtered and after getting an offset
they end up at the right end of the spectrum (more clever parser will
be added some day). There are definitely more solutions to the problem
and it is a nice puzzle to solve.</p>

<p>In the future more methods can be added, as there is practically no
limit to what goes into the tables. For that we will provide hooks.</p>

<p>Todo: decomposition with specific order of accents, this is
relatively easy to do.</p>

<p>Todo: investigate what standards and conventions there are and see
how they map onto this mechanism. I've learned that users can come up
with any demand so nothing here is frozen.</p>

<p>Todo: I ran into the Unicode Collation document and noticed that
there are some similarities (like the weights) but using that method
would still demand extra code for language specifics. One option is
to use the allkeys.txt file for the uc vectors but then we would also
use the collapsed key (sq, code is now commented). In fact, we could
just hook those into the replacer code that we reun beforehand.</p>

<p>In the future index entries will become more clever, i.e. they will
have language etc properties that then can be used.</p>
]]--

local gsub, find, rep, sub, sort, concat, tohash, format = string.gsub, string.find, string.rep, string.sub, table.sort, table.concat, table.tohash, string.format
local utfbyte, utfchar, utfcharacters, utfvalues = utf.byte, utf.char, utf.characters, utf.values
local next, type, tonumber, rawget, rawset = next, type, tonumber, rawget, rawset
local P, Cs, R, S, lpegmatch, lpegpatterns = lpeg.P, lpeg.Cs, lpeg.R, lpeg.S, lpeg.match, lpeg.patterns

local allocate          = utilities.storage.allocate
local setmetatableindex = table.setmetatableindex

local trace_tests       = false  trackers.register("sorters.tests",        function(v) trace_tests        = v end)
local trace_methods     = false  trackers.register("sorters.methods",      function(v) trace_methods      = v end)
local trace_orders      = false  trackers.register("sorters.orders",       function(v) trace_orders       = v end)
local trace_replacements= false  trackers.register("sorters.replacements", function(v) trace_replacements = v end)

local report_sorters    = logs.reporter("languages","sorters")

local comparers         = { }
local splitters         = { }
local definitions       = allocate()
local tracers           = allocate()
local ignoredoffset     = 0x10000 -- frozen
local replacementoffset = 0x10000 -- frozen
local digitsoffset      = 0x20000 -- frozen
local digitsmaximum     = 0xFFFFF -- frozen

local lccodes           = characters.lccodes
local uccodes           = characters.uccodes
local lcchars           = characters.lcchars
local ucchars           = characters.ucchars
local shchars           = characters.shchars
local fscodes           = characters.fscodes
local fschars           = characters.fschars

local decomposed        = characters.decomposed

local variables         = interfaces.variables

local v_numbers         = variables.numbers
local v_default         = variables.default
local v_before          = variables.before
local v_after           = variables.after
local v_first           = variables.first
local v_last            = variables.last

local validmethods      = tohash {
    "ch", -- raw character (for tracing)
    "mm", -- minus mapping
    "zm", -- zero  mapping
    "pm", -- plus  mapping
    "mc", -- lower case - 1
    "zc", -- lower case
    "pc", -- lower case + 1
    "uc", -- unicode
}

local predefinedmethods = {
    [v_default] = "zc,pc,zm,pm,uc",
    [v_before]  = "mm,mc,uc",
    [v_after]   = "pm,mc,uc",
    [v_first]   = "pc,mm,uc",
    [v_last]    = "mc,mm,uc",
}

sorters = {
    comparers    = comparers,
    splitters    = splitters,
    definitions  = definitions,
    tracers      = tracers,
    constants    = {
        ignoredoffset     = ignoredoffset,
        replacementoffset = replacementoffset,
        digitsoffset      = digitsoffset,
        digitsmaximum     = digitsmaximum,
        defaultlanguage   = v_default,
        defaultmethod     = v_default,
        defaultdigits     = v_numbers,
        validmethods      = validmethods,
    }
}

local sorters   = sorters
local constants = sorters.constants

local data, language, method, digits
local replacements, m_mappings, z_mappings, p_mappings, entries, orders, lower, upper, method, sequence, usedinsequence
local thefirstofsplit

local mte = { -- todo: assign to t
    __index = function(t,k)
        if k and k ~= "" and utfbyte(k) < digitsoffset then -- k check really needed (see s-lan-02)
            local el
            if k then
                local l = lower[k] or lcchars[k]
                el = rawget(t,l)
            end
            if not el then
                local l = shchars[k]
                if l and l ~= k then
                    if #l > 1 then
                        l = sub(l,1,1) -- todo
                    end
                    el = rawget(t,l)
                    if not el then
                        l = lower[k] or lcchars[l]
                        if l then
                            el = rawget(t,l)
                        end
                    end
                end
                el = el or k
            end
        --  rawset(t,k,el)
            return el
        else
        --  rawset(t,k,k)
        end
    end
}

local noorder = false
local nothing = { 0 }

local function preparetables(data)
    local orders, lower, m_mappings, z_mappings, p_mappings = data.orders, data.lower, { }, { }, { }
    for i=1,#orders do
        local oi = orders[i]
        local n = { 2 * i }
        m_mappings[oi], z_mappings[oi], p_mappings[oi] = n, n, n
    end
    local mtm = {
        __index = function(t,k)
            local n, nn
            if k then
                if trace_orders then
                    report_sorters("simplifing character %C",k)
                end
                local l = lower[k] or lcchars[k]
                if l then
                    if trace_orders then
                        report_sorters(" 1 lower: %C",l)
                    end
                    local ml = rawget(t,l)
                    if ml then
                        n = { }
                        nn = 0
                        for i=1,#ml do
                            nn = nn + 1
                            n[nn] = ml[i] + (t.__delta or 0)
                        end
                        if trace_orders then
                            report_sorters(" 2 order: % t",n)
                        end
                    end
                end
                if not n then
                    local s = shchars[k] -- maybe all components?
                    if s and s ~= k then
                        if trace_orders then
                            report_sorters(" 3 shape: %C",s)
                        end
                        n = { }
                        nn = 0
                        for l in utfcharacters(s) do
                            local ml = rawget(t,l)
                            if ml then
                                if trace_orders then
                                    report_sorters(" 4 keep: %C",l)
                                end
                                if ml then
                                    for i=1,#ml do
                                        nn = nn + 1
                                        n[nn] = ml[i]
                                    end
                                end
                            else
                                l = lower[l] or lcchars[l]
                                if l then
                                    if trace_orders then
                                        report_sorters(" 5 lower: %C",l)
                                    end
                                    local ml = rawget(t,l)
                                    if ml then
                                        for i=1,#ml do
                                            nn = nn + 1
                                            n[nn] = ml[i] + (t.__delta or 0)
                                        end
                                    end
                                end
                            end
                        end
                    else
                        -- this is a kind of last resort branch that we might want to revise
                        -- one day
                        --
                        -- local b = utfbyte(k)
                        -- n = decomposed[b] or { b }
                        -- if trace_tests then
                        --     report_sorters(" 6 split: %s",utf.tostring(b)) -- todo
                        -- end
                        --
                        -- we need to move way above valid order (new per 2014-10-16) .. maybe we
                        -- need to move it even more up to get numbers right (not all have orders)
                        --
                        if k == "\000" then
                            n = nothing -- shared
                            if trace_orders then
                                report_sorters(" 6 split: space") -- todo
                            end
                        else
                            local b = 2 * #orders + utfbyte(k)
                            n = decomposed[b] or { b } -- could be shared tables
                            if trace_orders then
                                report_sorters(" 6 split: %s",utf.tostring(b)) -- todo
                            end
                        end
                    end
                    if n then
                        if trace_orders then
                            report_sorters(" 7 order: % t",n)
                        end
                    else
                        n = noorder
                        if trace_orders then
                            report_sorters(" 8 order: 0")
                        end
                    end
                end
            else
                n = noorder
                if trace_orders then
                    report_sorters(" 9 order: 0")
                end
            end
            rawset(t,k,n)
            return n
        end
    }
    data.m_mappings = m_mappings
    data.z_mappings = z_mappings
    data.p_mappings = p_mappings
    m_mappings.__delta = -1
    z_mappings.__delta =  0
    p_mappings.__delta =  1
    setmetatable(data.entries,mte)
    setmetatable(data.m_mappings,mtm)
    setmetatable(data.z_mappings,mtm)
    setmetatable(data.p_mappings,mtm)
    thefirstofsplit = data.firstofsplit
end

local function update() -- prepare parent chains, needed when new languages are added
    for language, data in next, definitions do
        local parent = data.parent or "default"
        if language ~= "default" then
            setmetatableindex(data,definitions[parent] or definitions.default)
        end
        data.language   = language
        data.parent     = parent
        data.m_mappings = { } -- free temp data
        data.z_mappings = { } -- free temp data
        data.p_mappings = { } -- free temp data
    end
end

local function setlanguage(l,m,d,u) -- this will become a specification table (also keep this one as it's used in manuals)
    language = (l ~= "" and l) or constants.defaultlanguage
    data     = definitions[language or constants.defaultlanguage] or definitions[constants.defaultlanguage]
    method   = (m ~= "" and m) or (data.method ~= "" and data.method) or constants.defaultmethod
    digits   = (d ~= "" and d) or (data.digits ~= "" and data.digits) or constants.defaultdigits
    if trace_tests then
        report_sorters("setting language %a, method %a, digits %a",language,method,digits)
    end
    replacements = data.replacements
    entries      = data.entries
    orders       = data.orders
    lower        = data.lower
    upper        = data.upper
    preparetables(data)
    m_mappings   = data.m_mappings
    z_mappings   = data.z_mappings
    p_mappings   = data.p_mappings
    --
    method = predefinedmethods[variables[method]] or method
    data.method  = method
    --
    data.digits  = digits
    --
    local seq = utilities.parsers.settings_to_array(method or "") -- check the list
    sequence = { }
    local nofsequence = 0
    for i=1,#seq do
        local s = seq[i]
        if validmethods[s] then
            nofsequence = nofsequence + 1
            sequence[nofsequence] = s
        else
            report_sorters("invalid sorter method %a in %a",s,method)
        end
    end
    usedinsequence = tohash(sequence)
    data.sequence = sequence
    data.usedinsequence = usedinsequence
-- usedinsequence.ch = true -- better just store the string
    if trace_tests then
        report_sorters("using sort sequence: % t",sequence)
    end
    --
    return data
end

function sorters.update()
    update()
    setlanguage(language,method,numberorder) -- resync current language and method
end

function sorters.setlanguage(language,method,numberorder)
    update()
    setlanguage(language,method,numberorder) -- new language and method
end

-- tricky: { 0, 0, 0 } vs { 0, 0, 0, 0 } => longer wins and mm, pm, zm can have them

-- inlining and checking first slot first doesn't speed up (the 400K complex author sort)

local function basicsort(sort_a,sort_b)
    if sort_a and sort_b then
        local na = #sort_a
        local nb = #sort_b
        if na > nb then
            na = nb
        end
        if na > 0 then
            for i=1,na do
                local ai, bi = sort_a[i], sort_b[i]
                if ai > bi then
                    return  1
                elseif ai < bi then
                    return -1
                end
            end
        end
    end
    return 0
end

-- todo: compile compare function

local function basic(a,b) -- trace ea and eb
    if a == b then
        -- hashed (shared) entries
        return 0
    end
    local ea = a.split
    local eb = b.split
    local na = #ea
    local nb = #eb
    if na == 0 and nb == 0 then
        -- simple variant (single word)
        local result = 0
        for j=1,#sequence do
            local m = sequence[j]
            result = basicsort(ea[m],eb[m])
            if result ~= 0 then
                return result
            end
        end
        if result == 0 then
            local la = #ea.uc
            local lb = #eb.uc
            if la > lb then
                return 1
            elseif lb > la then
                return -1
            else
                return 0
            end
        else
            return result
        end
    else
        -- complex variant, used in register (multiple words)
        local result = 0
        for i=1,nb < na and nb or na do
            local eai = ea[i]
            local ebi = eb[i]
            for j=1,#sequence do
                local m = sequence[j]
                result = basicsort(eai[m],ebi[m])
                if result ~= 0 then
                    return result
                end
            end
            if result == 0 then
                local la = #eai.uc
                local lb = #ebi.uc
                if la > lb then
                    return 1
                elseif lb > la then
                    return -1
                end
            else
                return result
            end
        end
        if result ~= 0 then
            return result
        elseif na > nb then
            return 1
        elseif nb > na then
            return -1
        else
            return 0
        end
    end
end

-- if we use sq:
--
-- local function basic(a,b) -- trace ea and eb
--     local ea, eb = a.split, b.split
--     local na, nb = #ea, #eb
--     if na == 0 and nb == 0 then
--         -- simple variant (single word)
--         return basicsort(ea.sq,eb.sq)
--     else
--         -- complex variant, used in register (multiple words)
--         local result = 0
--         for i=1,nb < na and nb or na do
--             local eai, ebi = ea[i], eb[i]
--             result = basicsort(ea.sq,eb.sq)
--             if result ~= 0 then
--                 return result
--             end
--         end
--         if result ~= 0 then
--             return result
--         elseif na > nb then
--             return 1
--         elseif nb > na then
--             return -1
--         else
--             return 0
--         end
--     end
-- end

comparers.basic = basic

function sorters.basicsorter(a,b)
    return basic(a,b) == -1
end

local function numify(old)
    if digits == v_numbers then -- was swapped, fixed 2014-11-10
        local new = digitsoffset + tonumber(old) -- alternatively we can create range
        if new > digitsmaximum then
            new = digitsmaximum
        end
        return utfchar(new)
    else
        return old
    end
end

local pattern = nil

local function prepare() -- todo: test \Ux{hex}
    pattern = Cs( (
        characters.tex.toutfpattern()
      + lpeg.patterns.whitespace / "\000"
      + (P("\\Ux{") / "" * ((1-P("}"))^1/function(s) return utfchar(tonumber(s,16)) end) * (P("}")/""))
      + (P("\\") / "") * R("AZ")^0 * (P(-1) + #(1-R("AZ")))
      + (P("\\") * P(1) * R("az","AZ")^0) / ""
      + S("[](){}$\"'") / ""
      + R("09")^1 / numify
      + P(1)
    )^0 )
    return pattern
end

local function strip(str) -- todo: only letters and such
    if str and str ~= "" then
        return lpegmatch(pattern or prepare(),str)
    else
        return ""
    end
end

sorters.strip = strip

local function firstofsplit(entry)
    -- numbers are left padded by spaces
    local split = entry.split
    if #split > 0 then
        split = split[1].ch
    else
        split = split.ch
    end
    local first = split and split[1] or ""
    if thefirstofsplit then
        return thefirstofsplit(first,data,entry) -- normally the first one is needed
    else
        return first, entries[first] or "\000" -- tag
    end
end

sorters.firstofsplit = firstofsplit

-- for the moment we use an inefficient bunch of tables but once
-- we know what combinations make sense we can optimize this

function splitters.utf(str,checked) -- we could append m and u but this is cleaner, s is for tracing
    local nofreplacements = #replacements
    if nofreplacements > 0 then
        -- todo make an lpeg for this
        local replacer = replacements.replacer
        if not replacer then
            local rep = { }
            for i=1,nofreplacements do
                local r = replacements[i]
                rep[strip(r[1])] = strip(r[2])
            end
            replacer = lpeg.utfchartabletopattern(rep)
            replacer = Cs((replacer/rep + lpegpatterns.utf8character)^0)
            replacements.replacer = replacer
        end
        local rep = lpegmatch(replacer,str)
        if rep and rep ~= str then
            if trace_replacements then
                report_sorters("original   : %s",str)
                report_sorters("replacement: %s",rep)
            end
            str = rep
        end
     -- for k=1,#replacements do
     --     local v = replacements[k]
     --     local s = v[1]
     --     if find(str,s) then
     --         str = gsub(str,s,v[2])
     --     end
     -- end
    end
    local m_case    = { }
    local z_case    = { }
    local p_case    = { }
    local m_mapping = { }
    local z_mapping = { }
    local p_mapping = { }
    local char      = { }
    local byte      = { }
    local n         = 0
    local nm        = 0
    local nz        = 0
    local np        = 0
    for sc in utfcharacters(str) do
        local b = utfbyte(sc)
        if b >= digitsoffset then
            if n == 0 then
                -- we need to force number to the top
                z_case[1] = 0
                m_case[1] = 0
                p_case[1] = 0
                char[1] = sc
                byte[1] = 0
                m_mapping[1] = 0
                z_mapping[1] = 0
                p_mapping[1] = 0
                n = 2
            else
                n = n + 1
            end
            z_case[n] = b
            m_case[n] = b
            p_case[n] = b
            char[n] = sc
            byte[n] = b
            nm = nm + 1
            nz = nz + 1
            np = np + 1
            m_mapping[nm] = b
            z_mapping[nz] = b
            p_mapping[np] = b
        else
            n = n + 1
            local l = lower[sc]
            l = l and utfbyte(l) or lccodes[b] or b
         -- local u = upper[sc]
         -- u = u and utfbyte(u) or uccodes[b] or b
            if type(l) == "table" then
                l = l[1] -- there are currently no tables in lccodes but it can be some, day
            end
         -- if type(u) == "table" then
         --     u = u[1] -- there are currently no tables in lccodes but it can be some, day
         -- end
            z_case[n] = l
            if l ~= b then
                m_case[n] = l - 1
                p_case[n] = l + 1
            else
                m_case[n] = l
                p_case[n] = l
            end
            char[n], byte[n] = sc, b
            local fs = fscodes[b] or b
            local msc = m_mappings[sc]
            if msc ~= noorder then
                if not msc then
                    msc = m_mappings[fs]
                end
                for i=1,#msc do
                    nm = nm + 1
                    m_mapping[nm] = msc[i]
                end
            end
            local zsc = z_mappings[sc]
            if zsc ~= noorder then
                if not zsc then
                    zsc = z_mappings[fs]
                end
                for i=1,#zsc do
                    nz = nz + 1
                    z_mapping[nz] = zsc[i]
                end
            end
            local psc = p_mappings[sc]
            if psc ~= noorder then
                if not psc then
                    psc = p_mappings[fs]
                end
                for i=1,#psc do
                    np = np + 1
                    p_mapping[np] = psc[i]
                end
            end
        end
    end
    -- -- only those needed that are part of a sequence
    --
    -- local b = byte[1]
    -- if b then
    --     -- we set them to the first split code (korean)
    --     local fs = fscodes[b] or b
    --     if #m_mapping == 0 then
    --         m_mapping = { m_mappings[fs][1] }
    --     end
    --     if #z_mapping == 0 then
    --         z_mapping = { z_mappings[fs][1] }
    --     end
    --     if #p_mapping == 0 then
    --         p_mapping = { p_mappings[fs][1] }
    --     end
    -- end
    local result
    if checked then
        result = {
            ch = trace_tests       and char      or nil, -- not in sequence
            uc = usedinsequence.uc and byte      or nil,
            mc = usedinsequence.mc and m_case    or nil,
            zc = usedinsequence.zc and z_case    or nil,
            pc = usedinsequence.pc and p_case    or nil,
            mm = usedinsequence.mm and m_mapping or nil,
            zm = usedinsequence.zm and z_mapping or nil,
            pm = usedinsequence.pm and p_mapping or nil,
        }
    else
        result = {
            ch = char,
            uc = byte,
            mc = m_case,
            zc = z_case,
            pc = p_case,
            mm = m_mapping,
            zm = z_mapping,
            pm = p_mapping,
        }
    end
 -- local sq, n = { }, 0
 -- for i=1,#byte do
 --     for s=1,#sequence do
 --         n = n + 1
 --         sq[n] = result[sequence[s]][i]
 --     end
 -- end
 -- result.sq = sq
    return result
end

local function packch(entry)
    local split = entry.split
    if split and #split > 0 then -- useless test
        local t = { }
        for i=1,#split do
            local tt = { }
            local ch = split[i].ch
            for j=1,#ch do
                local chr = ch[j]
                local byt = utfbyte(chr)
                if byt > ignoredoffset then
                    tt[j] = "[]"
                elseif byt == 0 then
                    tt[j] = " "
                else
                    tt[j] = chr
                end
            end
            t[i] = concat(tt)
        end
        return concat(t," + ")
    else
        local t  = { }
        local ch = (split and split.ch) or entry.ch or entry
        if ch then
            for i=1,#ch do
                local chr = ch[i]
                local byt = utfbyte(chr)
                if byt > ignoredoffset then
                    t[i] = "[]"
                elseif byt == 0 then
                    t[i] = " "
                else
                    t[i] = chr
                end
            end
            return concat(t)
        else
            return ""
        end
    end
end

local function packuc(entry)
    local split = entry.split
    if split and #split > 0 then -- useless test
        local t = { }
        for i=1,#split do
            t[i] = concat(split[i].uc, " ") -- sq
        end
        return concat(t," + ")
    else
        local uc = (split and split.uc) or entry.uc or entry
        if uc then
            return concat(uc," ") -- sq
        else
            return ""
        end
    end
end

sorters.packch = packch
sorters.packuc = packuc

function sorters.sort(entries,cmp)
    if trace_methods then
        local nofentries = #entries
        report_sorters("entries: %s, language: %s, method: %s, digits: %s",nofentries,language,method,tostring(digits))
        for i=1,nofentries do
            report_sorters("entry %s",table.serialize(entries[i].split,i,true,true,true))
        end
    end
    if trace_tests then
        sort(entries,function(a,b)
            local r = cmp(a,b)
            local e = (not r and "?") or (r<0 and "<") or (r>0 and ">") or "="
            report_sorters("%s %s %s | %s %s %s",packch(a),e,packch(b),packuc(a),e,packuc(b))
            return r == -1
        end)
        local s
        for i=1,#entries do
            local entry = entries[i]
            local letter, first = firstofsplit(entry)
            if first == s then
                first = "  "
            else
                s = first
                if first and letter then
                    report_sorters(">> %C (%C)",first,letter)
                end
            end
            report_sorters("   %s | %s",packch(entry),packuc(entry))
        end
    else
        sort(entries,function(a,b)
            return cmp(a,b) == -1
        end)
    end
end

-- helper

function sorters.replacementlist(list)
    local replacements = { }
    for i=1,#list do
        replacements[i] = {
            list[i],
            utfchar(replacementoffset+i),
        }
    end
    return replacements
end
