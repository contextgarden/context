if not modules then modules = { } end modules ['publ-aut'] = {
    version   = 1.001,
    comment   = "this module part of publication support",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

if not characters then
    dofile(resolvers.findfile("char-def.lua"))
    dofile(resolvers.findfile("char-ini.lua"))
end

local context  = context
local chardata = characters.data

local tostring = tostring
local concat = table.concat
local lpeg = lpeg
local utfchar = utf.char

local P, C, V, Cs, Ct, lpegmatch, lpegpatterns = lpeg.P, lpeg.C, lpeg.V, lpeg.Cs, lpeg.Ct, lpeg.match, lpeg.patterns

local publications    = publications or { }

local datasets        = publications.datasets or { }
publications.datasets = datasets

publications.authors  = publications.authors or { }
local authors         = publications.authors

-- local function makesplitter(separator)
--     return Ct { "start",
--         start = (Cs((V("outer") + (1-separator))^1) + separator^1)^1,
--         start = Cs(V("outer")) + (Cs((V("inner") + (1-separator))^1) + separator^1)^1,
--         outer = (P("{")/"") * ((V("inner") + P(1-P("}")))^0) * (P("}")/""),
--         inner = P("{") * ((V("inner") + P(1-P("}")))^0) * P("}"),
--     }
-- end

local space          = P(" ")
local comma          = P(",")
local firstcharacter = lpegpatterns.utf8byte

-- local andsplitter    = lpeg.tsplitat(space^1 * "and" * space^1)
-- local commasplitter  = lpeg.tsplitat(space^0 * comma * space^0)
-- local spacesplitter  = lpeg.tsplitat(space^1)

local p_and         = space^1 * "and" * space^1
local p_comma       = space^0 * comma * space^0
local p_space       = space^1

local andsplitter   = Ct { "start",
    start = (Cs((V("inner") + (1-p_and))^1) + p_and)^1,
    inner = P("{") * ((V("inner") + P(1-P("}")))^1) * P("}"),
}

local commasplitter = Ct { "start",
    start = Cs(V("outer")) + (Cs((V("inner") + (1-p_comma))^1) + p_comma)^1,
    outer = (P("{")/"") * ((V("inner") + P(1-P("}")))^1) * (P("}")/""),
    inner = P("{") * ((V("inner") + P(1-P("}")))^1) * P("}"),
}

local spacesplitter = Ct { "start",
    start = Cs(V("outer")) + (Cs((V("inner") + (1-p_space))^1) + p_space)^1,
    outer = (P("{")/"") * ((V("inner") + P(1-P("}")))^1) * (P("}")/""),
    inner = P("{") * ((V("inner") + P(1-P("}")))^1) * P("}"),
}

local function is_upper(str)
    local first = lpegmatch(firstcharacter,str)
    local okay = chardata[first]
    return okay and okay.category == "lu"
end

local cache   = { } -- 33% reuse on tugboat.bib
local nofhits = 0
local nofused = 0

local function splitauthorstring(str)
    if not str then
        return
    end
    nofused = nofused + 1
    local authors = cache[str]
    if authors then
        -- hit 1
        -- print("hit 1",author,nofhits,nofused,math.round(100*nofhits/nofused))
        return { authors } -- we assume one author
    end
    local authors = lpegmatch(andsplitter,str)
    for i=1,#authors do
        local author = authors[i]
        local detail = cache[author]
        if detail then
            -- hit 2
            -- print("hit 2",author,nofhits,nofused,math.round(100*nofhits/nofused))
        end
        if not detail then
            local firstnames, vons, surnames, initials, juniors
            local split = lpegmatch(commasplitter,author)
-- inspect(split)
            local n = #split
            if n == 1 then
                -- First von Last
                local words = lpegmatch(spacesplitter,author)
                firstnames, vons, surnames = { }, { }, { }
                local i, n = 1, #words
                while i <= n do
                    local w = words[i]
                    if is_upper(w) then
                        firstnames[#firstnames+1], i = w, i + 1
                    else
                        break
                    end
                end
                while i <= n do
                    local w = words[i]
                    if is_upper(w) then
                        break
                    else
                        vons[#vons+1], i = w, i + 1
                    end
                end
                if i <= n then
                    while i <= n do
                        surnames[#surnames+1], i = words[i], i + 1
                    end
                elseif #vons == 0 then
                    surnames[1] = firstnames[#firstnames]
                    firstnames[#firstnames] = nil
                else
                    -- mess
                end
                -- safeguard
                if #surnames == 0 then
                    firstnames = { }
                    vons       = { }
                    surnames   = { author }
                end
            elseif n == 2 then
                -- von Last, First
                firstnames, vons, surnames = { }, { }, { }
                local words = lpegmatch(spacesplitter,split[1])
                local i, n = 1, #words
                while i <= n do
                    local w = words[i]
                    if is_upper(w) then
                        break
                    else
                        vons[#vons+1], i = w, i + 1
                    end
                end
                while i <= n do
                    surnames[#surnames+1], i = words[i], i + 1
                end
                --
                local words = lpegmatch(spacesplitter,split[2])
                local i, n = 1, #words
                while i <= n do
                    local w = words[i]
                    if is_upper(w) then
                        firstnames[#firstnames+1], i = w, i + 1
                    else
                        break
                    end
                end
                while i <= n do
                    vons[#vons+1], i = words[i], i + 1
                end
            else
                -- von Last, Jr ,First
                firstnames = lpegmatch(spacesplitter,split[1])
                juniors    = lpegmatch(spacesplitter,split[2])
                surnames   = lpegmatch(spacesplitter,split[3])
                if n > 3 then
                    -- error
                end
            end
            if #surnames == 0 then
                surnames[1] = firstnames[#firstnames]
                firstnames[#firstnames] = nil
            end
            if firstnames then
                initials = { }
                for i=1,#firstnames do
                    initials[i] = utfchar(lpegmatch(firstcharacter,firstnames[i]))
                end
            end
            detail = {
                original   = author,
                firstnames = firstnames,
                vons       = vons,
                surnames   = surnames,
                initials   = initials,
                juniors    = juniors,
            }
            cache[author] = detail
            nofhits = nofhits + 1
        end
        authors[i] = detail
    end
    return authors
end

-- local function splitauthors(dataset,tag,field)
--     local entries = datasets[dataset]
--     local luadata = entries.luadata
--     if not luadata then
--         return { }
--     end
--     local entry = luadata[tag]
--     if not entry then
--         return { }
--     end
--     return  splitauthorstring(entry[field])
-- end

local function the_initials(initials,symbol)
    local t, symbol = { }, symbol or "."
    for i=1,#initials do
        t[i] = initials[i] .. symbol
    end
    return t
end

-- authors

local settings = { }

-- local defaultsettings = {
--     firstnamesep        = " ",
--     initialsep          = " ",
--     vonsep              = " ",
--     surnamesep          = " ",
--     juniorsep           = " ",
--     surnamejuniorsep    = ", ",
--     juniorjuniorsep     = ", ",
--     surnamefirstnamesep = ", ",
--     surnameinitialsep   = ", ",
--     namesep             = ", ",
--     lastnamesep         = " and ",
--     finalnamesep        = " and ",
--     etallimit           = 1000,
--     etaldisplay         = 1000,
--     etaltext            = "",
-- }

local defaultsettings = {
    firstnamesep        = [[\btxlistvariantparameter{firstnamesep}]],
    vonsep              = [[\btxlistvariantparameter{vonsep}]],
    surnamesep          = [[\btxlistvariantparameter{surnamesep}]],
    juniorsep           = [[\btxlistvariantparameter{juniorsep}]],
    surnamejuniorsep    = [[\btxlistvariantparameter{surnamejuniorsep}]],
    juniorjuniorsep     = [[\btxlistvariantparameter{juniorjuniorsep}]],
    surnamefirstnamesep = [[\btxlistvariantparameter{surnamefirstnamesep}]],
    surnameinitialsep   = [[\btxlistvariantparameter{surnameinitialsep}]],
    initialsep          = [[\btxlistvariantparameter{initialsep}]],
    namesep             = [[\btxlistvariantparameter{namesep}]],
    lastnamesep         = [[\btxlistvariantparameter{lastnamesep}]],
    finalnamesep        = [[\btxlistvariantparameter{finalnamesep}]],
    --
    etaltext            = [[\btxlistvariantparameter{etaltext}]],
    --
    etallimit           = 1000,
    etaldisplay         = 1000,
}

function authors.setsettings(s)
end

authors.splitstring = splitauthorstring

-- [firstnames] [firstnamesep] [vons] [vonsep] [surnames] [juniors] [surnamesep]  (Taco, von Hoekwater, jr)

function authors.normal(author,settings)
    local firstnames, vons, surnames, juniors = author.firstnames, author.vons, author.surnames, author.juniors
    local result, settings = { }, settings or defaultsettings
    if firstnames and #firstnames > 0 then
        result[#result+1] = concat(firstnames," ")
        result[#result+1] = settings.firstnamesep or defaultsettings.firstnamesep
    end
    if vons and #vons > 0 then
        result[#result+1] = concat(vons," ")
        result[#result+1] = settings.vonsep or defaultsettings.vonsep
    end
    if surnames and #surnames > 0 then
        result[#result+1] = concat(surnames," ")
        if juniors and #juniors > 0 then
            result[#result+1] = settings.surnamejuniorsep or defaultsettings.surnamejuniorsep
            result[#result+1] = concat(juniors," ")
        end
    elseif juniors and #juniors > 0 then
        result[#result+1] = concat(juniors," ")
    end
    return concat(result)
end

-- [initials] [initialsep] [vons] [vonsep] [surnames] [juniors] [surnamesep]  (T, von Hoekwater, jr)

function authors.normalshort(author,settings)
    local initials, vons, surnames, juniors = author.initials, author.vons, author.surnames, author.juniors
    local result, settings = { }, settings or defaultsettings
    if initials and #initials > 0 then
        result[#result+1] = concat(the_initials(initials)," ")
        result[#result+1] = settings.initialsep or defaultsettings.initialsep
    end
    if vons and #vons > 0 then
        result[#result+1] = concat(vons," ")
        result[#result+1] = settings.vonsep or defaultsettings.vonsep
    end
    if surnames and #surnames > 0 then
        result[#result+1] = concat(surnames," ")
        if juniors and #juniors > 0 then
            result[#result+1] = settings.surnamejuniorsep or defaultsettings.surnamejuniorsep
            result[#result+1] = concat(juniors," ")
        end
    elseif juniors and #juniors > 0 then
        result[#result+1] = concat(juniors," ")
    end
    return concat(result)
end

-- [vons] [vonsep] [surnames] [surnamejuniorsep] [juniors] [surnamefirstnamesep] [firstnames] (von Hoekwater jr, Taco)

function authors.inverted(author,settings)
    local firstnames, vons, surnames, juniors = author.firstnames, author.vons, author.surnames, author.juniors
    local result, settings = { }, settings or defaultsettings
    if vons and #vons > 0 then
        result[#result+1] = concat(vons," ")
        result[#result+1] = settings.vonsep or defaultsettings.vonsep
    end
    if surnames and #surnames > 0 then
        result[#result+1] = concat(surnames," ")
        if juniors and #juniors > 0 then
            result[#result+1] = settings.surnamejuniorsep or defaultsettings.surnamejuniorsep
            result[#result+1] = concat(juniors," ")
        end
    elseif juniors and #juniors > 0 then
        result[#result+1] = concat(juniors," ")
    end
    if firstnames and #firstnames > 0 then
        result[#result+1] = settings.surnamefirstnamesep or defaultsettings.surnamefirstnamesep
        result[#result+1] = concat(firstnames," ")
    end
    return concat(result)
end

-- [vons] [vonsep] [surnames] [surnamejuniorsep] [juniors] [surnamefirstnamesep] [initials] (von Hoekwater jr, T)

function authors.invertedshort(author,settings)
    local vons, surnames, initials, juniors = author.vons, author.surnames, author.initials, author.juniors
    local result, settings = { }, settings or defaultsettings
    if vons and #vons > 0 then
        result[#result+1] = concat(vons," ")
        result[#result+1] = settings.vonsep or defaultsettings.vonsep
    end
    if surnames and #surnames > 0 then
        result[#result+1] = concat(surnames," ")
        if juniors and #juniors > 0 then
            result[#result+1] = settings.surnamejuniorsep or defaultsettings.surnamejuniorsep
            result[#result+1] = concat(juniors," ")
        end
    elseif juniors and #juniors > 0 then
        result[#result+1] = concat(juniors," ")
    end
    if initials and #initials > 0 then
        result[#result+1] = settings.surnameinitialsep or defaultsettings.surnameinitialsep
        result[#result+1] = concat(the_initials(initials)," ")
    end
    return concat(result)
end

-- [vons] [vonsep] [surnames]

function authors.name(author,settings)
    local vons, surnames = author.vons, author.surnames
    local result, settings = { }, settings or defaultsettings
    if vons and #vons > 0 then
        result[#result+1] = concat(vons," ")
        result[#result+1] = settings.vonsep or defaultsettings.vonsep
    end
    if surnames and #surnames > 0 then
        result[#result+1] = concat(surnames," ")
        if juniors and #juniors > 0 then
            result[#result+1] = settings.surnamejuniorsep or defaultsettings.surnamejuniorsep
            result[#result+1] = concat(juniors," ")
        end
    end
    return concat(result)
end

local lastconcatsize = 1

local function concatnames(t,settings)
    local namesep      = settings.namesep
    local lastnamesep  = settings.lastnamesep
    local finalnamesep = settings.finalnamesep
    local lastconcatsize = #t
    if lastconcatsize > 2 then
        local s = { }
        for i=1,lastconcatsize-2 do
            s[i] = t[i] .. namesep
        end
        s[lastconcatsize-1], s[lastconcatsize] = t[lastconcatsize-1] .. finalnamesep, t[lastconcatsize]
        return concat(s)
    elseif lastconcatsize > 1 then
        return concat(t,lastnamesep)
    elseif lastconcatsize > 0 then
        return t[1]
    else
        return ""
    end
end

function authors.concat(dataset,tag,field,settings)
    table.setmetatableindex(settings,defaultsettings)
    local combiner = settings.combiner
    if not combiner or type(combiner) == "string" then
        combiner = authors[combiner or "normal"] or authors.normal
    end
    local split       = datasets[dataset].details[tag][field]
    local etallimit   = settings.etallimit   or 1000
    local etaldisplay = settings.etaldisplay or etallimit
    local max = split and #split or 0
    if max == 0 then
        -- error
    end
    if max > etallimit and etaldisplay < max then
        max = etaldisplay
    end
    local combined = { }
    for i=1,max do
        combined[i] = combiner(split[i],settings)
    end
    local result = concatnames(combined,settings)
    if #combined <= max then
        return result
    else
        return result .. settings.etaltext
    end
end

function commands.btxauthor(...)
    context(authors.concat(...))
end

-- We can consider creating a hashtable key -> entry but I wonder if
-- pays off.

local compare  = sorters.comparers.basic -- (a,b)
local strip    = sorters.strip
local splitter = sorters.splitters.utf

-- authors(s) | year | journal | title | pages

local pubsorters = { }
authors.sorters  = pubsorters

-- local function assemble(snippets,key)
--     -- maybe an option is to also sort the authors first
--     if not key then
--         return ""
--     end
--     local n = #key
--     if n == 0 then
--         return ""
--     end
--     local s = 0
--     for i=1,n do
--         local k = key[i]
--         local vons     = k.vons
--         local surnames = k.surnames
--         local initials = k.initials
--         if vons and #vons > 0 then
--             s = s + 1 ; snippets[s] = concat(vons," ")
--         end
--         if surnames and #surnames > 0 then
--             s = s + 1 ; snippets[s] = concat(surnames," ")
--         end
--         if initials and #initials > 0 then
--             s = s + 1 ; snippets[s] = concat(initials," ")
--         end
--     end
--     local result = concat(snippets," ",1,s)
--     return strip(result)
-- end

-- local function byauthor(dataset,list,sorttype_a,sorttype_b,sorttype_c)
--     local luadata  = datasets[dataset].luadata
--     local details  = datasets[dataset].details
--     local valid    = { }
--     local splitted = { }
--     table.setmetatableindex(splitted,function(t,k) -- could be done in the sorter but seldom that many shared
--         local v = splitter(k,true)                 -- in other cases
--         t[k] = v
--         return v
--     end)
--     local snippets = { }
--     for i=1,#list do
--         -- either { tag, tag, ... } or { { tag, index }, { tag, index } }
--         local li        = list[i]
--         local tag       = type(li) == "string" and li or li[1]
--         local entry     = luadata[tag]
--         local detail    = details[tag]
--         local suffix    = tostring(i)
--         local year      = nil
--         local assembled = nil
--         if entry and detail then
--             assembled = assemble(snippets,detail.author or detail.editor)
--             year      = entry.year or "9998"
--         else
--             assembled = ""
--             year      = "9999"
--         end
--         valid[i] = {
--             index  = i,
--             split  = {
--                 splitted[strip(assembled)],
--                 splitted[year],
--                 splitted[suffix],
--                 splitted[entry.journal or ""],
--                 splitted[entry.title   or ""],
--                 splitted[entry.pages   or ""],
--             },
--         }
--     end
--     return valid
-- end

local function writer(snippets,key)
    if not key then
        return ""
    end
    local n = #key
    if n == 0 then
        return ""
    end
    local s = 0
    for i=1,n do
        local k = key[i]
        local vons     = k.vons
        local surnames = k.surnames
        local initials = k.initials
        if vons and #vons > 0 then
            s = s + 1 ; snippets[s] = concat(vons," ")
        end
        if surnames and #surnames > 0 then
            s = s + 1 ; snippets[s] = concat(surnames," ")
        end
        if initials and #initials > 0 then
            s = s + 1 ; snippets[s] = concat(initials," ")
        end
    end
    local result = concat(snippets," ",1,s)
    return strip(result)
end

local function newsplitter(splitter)
    return table.setmetatableindex({},function(t,k) -- could be done in the sorter but seldom that many shared
        local v = splitter(k,true)                  -- in other cases
        t[k] = v
        return v
    end)
end

local function byauthor(dataset,list,method) -- todo: yearsuffix
    local luadata  = datasets[dataset].luadata
    local details  = datasets[dataset].details
    local result   = { }
    local splitted = newsplitter(splitter) -- saves mem
    local snippets = { } -- saves mem
    for i=1,#list do
        -- either { tag, tag, ... } or { { tag, index }, { tag, index } }
        local li     = list[i]
        local tag    = type(li) == "string" and li or li[1]
        local entry  = luadata[tag]
        local detail = details[tag]
        if entry and detail then
            result[i] = {
                index  = i,
                split  = {
                    splitted[writer(snippets,detail.author or detail.editor or "")],
                    splitted[entry.year     or "9998"],
                    splitted[entry.journal  or ""],
                    splitted[entry.title    or ""],
                    splitted[entry.pages    or ""],
                    splitted[tostring(i)],
                },
            }
        else
            result[i] = {
                index  = i,
                split  = {
                    splitted[""],
                    splitted["9999"],
                    splitted[""],
                    splitted[""],
                    splitted[""],
                    splitted[tostring(i)],
                },
            }
        end
    end
    return result
end

authors.sorters.author = byauthor

function authors.sorted(dataset,list,sorttype) -- experimental
    local valid = byauthor(dataset,list,sorttype)
    if #valid == 0 or #valid ~= #list then
        return list
    else
        sorters.sort(valid,compare)
        for i=1,#valid do
            valid[i] = valid[i].index
        end
        return valid
    end
end

-- local dataset = publications.datasets.test
--
-- local function add(str)
--     dataset.details[str] = { author = publications.authors.splitstring(str) }
-- end
--
-- add("Hagen, Hans and Hoekwater, Taco Whoever T. Ex. and Henkel Hut, Hartmut Harald von der")
-- add("Hans Hagen and Taco Whoever T. Ex. Hoekwater  and Hartmut Harald von der Henkel Hut")
-- add("de Gennes, P. and Gennes, P. de")
-- add("van't Hoff, J. H. and {van't Hoff}, J. H.")
--
-- local list = table.keys(dataset.details)
-- local sort = publications.authors.sorted("test",list,"author")
-- local test = { } for i=1,#sort do test[i] = dataset.details[list[sort[i]]] end
