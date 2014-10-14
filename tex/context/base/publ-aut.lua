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

local lpeg = lpeg

local context  = context
local chardata = characters.data

local tostring = tostring
local concat = table.concat
local utfchar = utf.char
local formatters = string.formatters

local P, C, V, Cs, Ct, lpegmatch, lpegpatterns = lpeg.P, lpeg.C, lpeg.V, lpeg.Cs, lpeg.Ct, lpeg.match, lpeg.patterns

local publications    = publications or { }

local datasets        = publications.datasets or { }
publications.datasets = datasets

local writers         = publications.writers or { }
publications.writers  = writers

local authors         = publications.authors or { }
publications.authors  = authors

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

authors.splitstring = splitauthorstring

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
--     return splitauthorstring(entry[field])
-- end

local function the_initials(initials,symbol)
    if not symbol or symbol == "" then
        return initials
    else
        local result = { }
        for i=1,#initials do
            result[i] = initials[i] .. symbol
        end
        return result
    end
end

local ctx_btxsetconcat        = context.btxsetconcat
local ctx_btxsetauthorindex   = context.btxsetauthorindex
local ctx_btxsetoverflow      = context.btxsetoverflow
local ctx_btxsetinitials      = context.btxsetinitials
local ctx_btxsetfirstnames    = context.btxsetfirstnames
local ctx_btxsetvons          = context.btxsetvons
local ctx_btxsetsurnames      = context.btxsetsurnames
local ctx_btxsetjuniors       = context.btxsetjuniors
local ctx_btxciteauthorsetup  = context.btxciteauthorsetup
local ctx_btxlistauthorsetup  = context.btxlistauthorsetup
local ctx_btxsetauthorvariant = context.btxsetauthorvariant
local ctx_btxstartauthor      = context.btxstartauthor
local ctx_btxstopauthor       = context.btxstopauthor

local concatstate = publications.concatstate
local f_invalid   = formatters["<invalid %s: %s>"]

local currentauthordata   = nil
local currentauthorsymbol = nil

local manipulators       = typesetters.manipulators
local splitmanipulation  = manipulators.splitspecification
local applymanipulation  = manipulators.applyspecification
local manipulatormethods = manipulators.methods

local function value(i,field)
    if currentauthordata then
        local entry = currentauthordata[i]
        if entry then
            local value = entry[field]
            if value and #value > 0 then
                return value
            end
        end
    end
end

function commands.btx_a_i(i) local v = value(i,"initials")   if v then context(concat(the_initials(v,currentauthorsymbol or "."))) end end
function commands.btx_a_f(i) local v = value(i,"firstnames") if v then context(concat(v," ")) end end
function commands.btx_a_j(i) local v = value(i,"juniors")    if v then context(concat(v," ")) end end
function commands.btx_a_s(i) local v = value(i,"surnames")   if v then context(concat(v," ")) end end
function commands.btx_a_v(i) local v = value(i,"vons")       if v then context(concat(v," ")) end end

function commands.btxauthorfield(i,field)
    if currentauthordata then
        local entry = currentauthordata[i]
        if entry then
            local manipulator, field = splitmanipulation(field)
            local value = entry[field]
            if not value or #value == 0 then
                -- value, no need for message
            elseif manipulator then
                for i=1,#value do
                    if i > 1 then
                        context(" ") -- symbol ?
                    end
                    context(applymanipulation(manipulator,value) or value)
                end
            elseif field == "initials" then
                context(concat(the_initials(value,currentauthorsymbol or ".")))
            else
                context(concat(value," "))
            end
         end
    end
end

function commands.btxauthor(dataset,tag,field,settings)
    local ds = datasets[dataset]
    if not ds then
        return f_invalid("dataset",dataset)
    end
    local dt = ds.details[tag]
    if not dt then
        return f_invalid("details",tag)
    end
    local split = dt[field]
    if not split then
        return f_invalid("field",field)
    end
    local max = split and #split or 0
    if max == 0 then
        return
        -- error
    end
    local etallimit   = tonumber(settings.etallimit) or 1000
    local etaldisplay = tonumber(settings.etaldisplay) or etallimit
    local combiner    = settings.combiner
    local symbol      = settings.symbol
    if not combiner or combiner == "" then
        combiner = "normal"
    end
    if not symbol then
        symbol = "."
    end
    local ctx_btxsetup = settings.kind == "cite" and ctx_btxciteauthorsetup or ctx_btxlistauthorsetup
    if max > etallimit and etaldisplay < max then
        max = etaldisplay
    end
    currentauthordata   = split
    currentauthorsymbol = symbol
    for i=1,max do
        local author = split[i]
        local state = author.state or 0
        ctx_btxstartauthor(i,max,state)
        ctx_btxsetconcat(concatstate(i,max))
        ctx_btxsetauthorvariant(combiner)
        local initials = author.initials
        if initials and #initials > 0 then
            ctx_btxsetinitials() -- (concat(the_initials(initials,symbol)," "))
        end
        local firstnames = author.firstnames
        if firstnames and #firstnames > 0 then
            ctx_btxsetfirstnames() -- (concat(firstnames," "))
        end
        local vons = author.vons
        if vons and #vons > 0 then
            ctx_btxsetvons() -- (concat(vons," "))
        end
        local surnames = author.surnames
        if surnames and #surnames > 0 then
            ctx_btxsetsurnames() -- (concat(surnames," "))
        end
        local juniors = author.juniors
        if juniors and #juniors > 0 then
            ctx_btxsetjuniors() -- (concat(juniors," "))
        end
        if i == max then
            local overflow = #split - max
            if overflow > 0 then
                ctx_btxsetoverflow(overflow)
            end
        end
        ctx_btxsetup(combiner)
        ctx_btxstopauthor()
    end
end

-- We can consider creating a hashtable key -> entry but I wonder if
-- pays off.

local compare  = sorters.comparers.basic -- (a,b)
-- local compare  = sorters.basicsorter -- (a,b)
local strip    = sorters.strip
local splitter = sorters.splitters.utf

-- authors(s) | year | journal | title | pages

local pubsorters = { }
authors.sorters  = pubsorters

local function writer(key,snippets)
    if not key then
        return ""
    end
    local n = #key
    if n == 0 then
        return ""
    end
    if not snippets then
        snippets = { }
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
    return concat(snippets," ",1,s)
end

writers.author = writer
writers.editor = editor

local function newsplitter(splitter)
    return table.setmetatableindex({},function(t,k) -- could be done in the sorter but seldom that many shared
        local v = splitter(k,true)                  -- in other cases
        t[k] = v
        return v
    end)
end

local function byauthor(dataset,list,method)
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
                    splitted[strip(writer(detail.author or detail.editor or "",snippets))],
                    splitted[entry.year or "9998"],
                    splitted[detail.suffix or " "],
                    splitted[strip(entry.journal or "")],
                    splitted[strip(entry.title or "")],
                    splitted[entry.pages or ""],
                    splitted[tostring(i)],
                },
            }
        else
            result[i] = {
                index  = i,
                split  = {
                    splitted[""],
                    splitted["9999"],
                    splitted[" "],
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

authors.sorters.writer = writer
authors.sorters.author = byauthor

function authors.sorted(dataset,list,sorttype) -- experimental
    local valid = byauthor(dataset,list,sorttype)
    if #valid == 0 or #valid ~= #list then
        return list
    else
        sorters.sort(valid,function(a,b) return a ~= b and compare(a,b) == -1 end)
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
