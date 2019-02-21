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

local type, next, tostring, tonumber = type, next, tostring, tonumber
local concat, sortedhash = table.concat, table.sortedhash
local utfsub = utf.sub
local find = string.find
local formatters = string.formatters

local P, S, C, V, Cs, Ct, Cg, Cf, Cc = lpeg.P, lpeg.S, lpeg.C, lpeg.V, lpeg.Cs, lpeg.Ct, lpeg.Cg, lpeg.Cf, lpeg.Cc
local lpegmatch, lpegpatterns = lpeg.match, lpeg.patterns
local settings_to_hash = utilities.parsers.settings_to_hash

local context         = context
----- commands        = commands

local implement       = interfaces.implement

local publications    = publications

local datasets        = publications.datasets
local getcasted       = publications.getcasted

local allocate        = utilities.storage.allocate

local chardata        = characters.data

local trace_hashing   = false  trackers.register("publications.authorhash", function(v) trace_hashing = v end)

local expand_authors  = false  directives.register("publications.prerollauthor", function(v) expand_authors = v end)

local report          = logs.reporter("publications","authors")
local report_cite     = logs.reporter("publications","cite")

local v_last          = interfaces.variables.last

-- local function makesplitter(separator)
--     return Ct { "start",
--         start = (Cs((V("outer") + (1-separator))^1) + separator^1)^1,
--         start = Cs(V("outer")) + (Cs((V("inner") + (1-separator))^1) + separator^1)^1,
--         outer = (P("{")/"") * ((V("inner") + P(1-P("}")))^0) * (P("}")/""),
--         inner = P("{") * ((V("inner") + P(1-P("}")))^0) * P("}"),
--     }
-- end

-- authorlist = { authorspec and authorspec and authorspec }
-- authorspec = composedname
-- authorspec = surnames, firstnames
-- authorspec = von, surnames, firstnames
-- authorspec = von, surnames, jr, firstnames
-- authorspec = von, surnames, jr, firstnames, initials

local space          = lpegpatterns.whitespace
local comma          = P(",")
local period         = P(".") + P("{.}")
local dash           = P("-") + P("{-}")
local firstcharacter = lpegpatterns.utf8byte
local utf8character  = lpegpatterns.utf8character
local p_and          = space^1 * (P("and") + P("&&") + P("++")) * space^1
local p_comma        = space^0 * comma * space^0
local p_space        = space^1
local p_shortone     = C((utf8character      -dash-period)^1)
local p_longone      = C( utf8character) * (1-dash-period)^0

local p_empty        = P("{}")/"" * #(p_space^0 * (P(-1) + P(",")))

local andsplitter   = Ct { "start",
    start = (Cs((V("inner") + (1-p_and))^1) + p_and)^1,
    inner = P("{") * ((V("inner") + P(1-P("}")))^1) * P("}"),
}

local commasplitter = Ct { "start",
    start = Cs(V("outer")) + (p_empty + Cs((V("inner") + (1-p_comma))^1) + p_comma)^1,
    outer = (P("{")/"") * ((V("inner") + P(1-P("}")))^1) * ((P("}") * P(-1))/""),
    inner = P("{") * ((V("inner") + P(1-P("}")))^1) * P("}"),
}

local spacesplitter = Ct { "start",
    start = Cs(V("outer")) + (Cs((V("inner") + (1-p_space))^1) + p_space)^1,
    outer = (P("{")/"") * ((V("inner") + P(1-P("}")))^1) * ((P("}") * P(-1))/""),
    inner = P("{") * ((V("inner") + P(1-P("}")))^1) * P("}"),
}

local p_initial       = p_shortone * period * dash^0
                      + p_longone * (period + dash + P(-1))
local initialsplitter = p_initial * P(-1) + Ct((p_initial)^1)

local optionsplitter  = Cf(Ct("") * Cg(C((1-space)^1) * space^0 * Cc(true))^1,rawset)

local function is_upper(str)
    local first = lpegmatch(firstcharacter,str)
    local okay = chardata[first]
    return okay and okay.category == "lu"
end

-- local cleaner = Cs( ( P("{}")/"" + P(1) )^1 )

local cache   = allocate() -- 33% reuse on tugboat.bib
local nofhits = 0
local nofused = 0

publications.authorcache = cache

local function makeinitials(firstnames)
    if firstnames and #firstnames > 0 then
        local initials = { }
        for i=1,#firstnames do
            initials[i] = lpegmatch(initialsplitter,firstnames[i])
        end
        return initials
    end
end

local authormap        = allocate()
publications.authormap = authormap

local prerollcmdstring = publications.prerollcmdstring

local function splitauthor(author,justsplit)
    local detail, remapped
    if not justsplit then
        detail = cache[author]
        if detail then
            return detail
        end
        remapped = authormap[author]
        if remapped then
            report("remapping %a to %a",author,remapped)
            local detail = cache[remapped]
            if detail then
                cache[author] = detail
                return detail
            end
        end
    end
    local author = remapped or author
    local firstnames, vons, surnames, initials, juniors, options
    if expand_authors and find(author,"\\btxcmd") then
        author = prerollcmdstring(author)
    end
    local split = lpegmatch(commasplitter,author)
    local n = #split
    detail = {
        original = author,
        snippets = n,
    }
    if n == 1 then
        -- {First Middle von Last}
        local words = lpegmatch(spacesplitter,author)
        local i     = 1
        local n     = #words
        firstnames  = { }
        vons        = { }
        surnames    = { }
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
        if #surnames == 0 then
            -- safeguard
            firstnames = { }
            vons       = { }
            surnames   = { author }
        else
            initials = makeinitials(firstnames)
        end
    elseif n == 2 then
        -- {Last, First}
        -- {von Last, First}
        local words = lpegmatch(spacesplitter,split[1])
        local i     = 1
        local n     = #words
        firstnames = { }
        vons       = { }
        surnames   = { }
        while i <= n do
            local w = words[i]
            if is_upper(w) then
                break
            else
                vons[#vons+1], i = w, i + 1
            end
        end
        while i <= n do
            surnames[#surnames+1] = words[i]
            i = i + 1
        end
        --
        local words = lpegmatch(spacesplitter,split[2])
        local i     = 1
        local n     = #words
        while i <= n do
            local w = words[i]
            if is_upper(w) then
                firstnames[#firstnames+1] = w
                i = i + 1
            else
                break
            end
        end
        while i <= n do
            vons[#vons+1] = words[i]
            i = i + 1
        end
        if surnames and firstnames and #surnames == 0 then
            -- safeguard
            surnames[1] = firstnames[#firstnames]
            firstnames[#firstnames] = nil
        end
        initials = makeinitials(firstnames)
    elseif n == 3 then
        -- {von Last, First, Jr}
        surnames   = lpegmatch(spacesplitter,split[1])
        juniors    = lpegmatch(spacesplitter,split[2])
        firstnames = lpegmatch(spacesplitter,split[3])
        initials   = makeinitials(firstnames)
    elseif n == 4 then
        -- {Von, Last, First, Jr}
        vons       = lpegmatch(spacesplitter,split[1])
        surnames   = lpegmatch(spacesplitter,split[2])
        juniors    = lpegmatch(spacesplitter,split[3])
        firstnames = lpegmatch(spacesplitter,split[4])
        initials   = makeinitials(firstnames)
    elseif n >= 5 then
        -- {Von, Last, First, Jr, F.}
        -- {Von, Last, First, Jr, Fr., options}
        vons       = lpegmatch(spacesplitter,split[1])
        surnames   = lpegmatch(spacesplitter,split[2])
        juniors    = lpegmatch(spacesplitter,split[3])
        firstnames = lpegmatch(spacesplitter,split[4])
        initials   = lpegmatch(spacesplitter,split[5])
        options    = split[6]
        if options then
            options = lpegmatch(optionsplitter,options)
        end
    end
    if firstnames and #firstnames > 0 then detail.firstnames = firstnames end
    if vons       and #vons       > 0 then detail.vons       = vons       end
    if surnames   and #surnames   > 0 then detail.surnames   = surnames   end
    if initials   and #initials   > 0 then detail.initials   = initials   end
    if juniors    and #juniors    > 0 then detail.juniors    = juniors    end
    if options    and next(options)   then detail.options    = options    end
    if not justsplit then
        cache[author] = detail
        nofhits = nofhits + 1
    end
    return detail
end

local function splitauthorstring(str)
    if not str or str == "" then
        return
    end
    nofused = nofused + 1

    local remapped = authormap[str]
    if remapped then
        local detail = cache[remapped]
        if detail then
            cache[str] = detail
            return { detail }
        end
    end

    local authors = cache[str]
    if authors then
        return { authors } -- we assume one author
    end

    -- we could cache these too but it can become messy .. leave that for later

    local authors    = lpegmatch(andsplitter,str) or { } -- maybe fake an author
    local nofauthors = #authors
    for i=1,nofauthors do
        authors[i] = splitauthor(authors[i])
    end
    if nofauthors > 1 and authors[nofauthors].original == "others" then
        -- only the last one is looked at
        authors[nofauthors] = nil
        authors.others      = true
    end
    return authors
end

publications.splitoneauthor = splitauthor
publications.splitauthor    = splitauthorstring

local function the_initials(initials,symbol,connector)
    if not symbol then
        symbol = "."
    end
    if not connector then
        connector = "-"
    end
    local result = { }
    local r      = 0
    for i=1,#initials do
        local initial = initials[i]
        if type(initial) == "table" then
            -- J.-J.
            local set = { }
            local s   = 0
            for i=1,#initial do
                if i > 1 then
                    s = s + 1 ; set[s] = connector
                end
                s = s + 1 ; set[s] = initial[i]
                s = s + 1 ; set[s] = symbol
            end
            r = r + 1 ; result[r] = concat(set)
        else
            -- J.
            r = r + 1 ; result[r] = initial .. symbol
        end
    end
    return result
end

local ctx_btxsetconcat        = context.btxsetconcat
local ctx_btxsetoverflow      = context.btxsetoverflow
local ctx_btxsetinitials      = context.btxsetinitials
local ctx_btxsetfirstnames    = context.btxsetfirstnames
local ctx_btxsetvons          = context.btxsetvons
local ctx_btxsetsurnames      = context.btxsetsurnames
local ctx_btxsetjuniors       = context.btxsetjuniors
local ctx_btxsetauthorvariant = context.btxsetauthorvariant

local ctx_btxstartauthor      = context.btxstartauthor
local ctx_btxstopauthor       = context.btxstopauthor

local ctx_btxciteauthorsetup  = context.btxciteauthorsetup
local ctx_btxlistauthorsetup  = context.btxlistauthorsetup

local concatstate = publications.concatstate
local f_invalid   = formatters["<invalid %s: %s>"]

local currentauthordata      = nil
local currentauthorsymbol    = nil
local currentauthorconnector = nil

local manipulators       = typesetters.manipulators
local splitmanipulation  = manipulators.splitspecification
local applymanipulation  = manipulators.applyspecification

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

implement { name = "btxcurrentfirstnames", arguments = "integer", actions = function(i) local v = value(i,"firstnames") if v then context(concat(v," ")) end end }
implement { name = "btxcurrentinitials",   arguments = "integer", actions = function(i) local v = value(i,"initials")   if v then context(concat(the_initials(v,currentauthorsymbol,currentauthorconnector))) end end }
implement { name = "btxcurrentjuniors",    arguments = "integer", actions = function(i) local v = value(i,"juniors")    if v then context(concat(v," ")) end end }
implement { name = "btxcurrentsurnames",   arguments = "integer", actions = function(i) local v = value(i,"surnames")   if v then context(concat(v," ")) end end }
implement { name = "btxcurrentvons",       arguments = "integer", actions = function(i) local v = value(i,"vons")       if v then context(concat(v," ")) end end }

local function btxauthorfield(i,field)
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
                        context(" ")
                    end
                    context(applymanipulation(manipulator,value) or value)
                end
            elseif field == "initials" then
                context(concat(the_initials(value,currentauthorsymbol,currentauthorconnector)))
            else
                context(concat(value," "))
            end
        end
    end
end

-- This is somewhat tricky: an author is not always an author but
-- can also be a title or key, depending on the (optional) set it's
-- in. Also, authors can be combined with years and so and they
-- might be called upon mixed with other calls.

local function btxauthor(dataset,tag,field,settings)
    local split, usedfield, kind = getcasted(dataset,tag,field)
    if kind == "author" then
        local max = split and #split or 0
        if max == 0 then
            return
            -- error
        end
        local absmax      = max
        local etallimit   = tonumber(settings.etallimit) or 1000
        local etaldisplay = tonumber(settings.etaldisplay) or etallimit
        local etaloption  = settings_to_hash(settings.etaloption or "")
        local etallast    = etaloption[v_last]
        local combiner    = settings.combiner
        local symbol      = settings.symbol
        local connector   = settings.connector
        local index       = settings.index
        if not combiner or combiner == "" then
            combiner = "normal"
        end
        if not symbol then
            symbol = "."
        end
        local ctx_btxsetup = settings.kind == "cite" and ctx_btxciteauthorsetup or ctx_btxlistauthorsetup
        if max > etallimit and (etaldisplay+(etallast and 1 or 0)) < max then
            max = etaldisplay
        else
            etallast = false
        end
        currentauthordata      = split
        currentauthorsymbol    = symbol
        currentauthorconnector = connector

        local function oneauthor(i,last,justone)
            local author = split[i]
            if index then
                ctx_btxstartauthor(i,1,0)
            elseif last then
                ctx_btxstartauthor(i,1,0)
                ctx_btxsetconcat(0)
                ctx_btxsetauthorvariant(combiner)
            else
                local state = author.state or 0
                ctx_btxstartauthor(i,max,state)
                ctx_btxsetconcat(concatstate(i,max))
                ctx_btxsetauthorvariant(combiner)
            end
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
            if not index and i == max then
                if split.others then
                    ctx_btxsetoverflow(1)
                else
                    local overflow = #split - max
                    if overflow > 0 then
                        ctx_btxsetoverflow(overflow)
                    end
                end
            end
            ctx_btxsetup(combiner)
            ctx_btxstopauthor()
        end
        if index then
            oneauthor(index)
        elseif max == 1 then
            oneauthor(1,false,true)
        else
            for i=1,max do
                oneauthor(i)
            end
            if etallast then
                oneauthor(absmax,true)
            end
        end
    else
        report("ignored field %a of tag %a, used field %a is no author",field,tag,usedfield)
    end
end

implement {
    name      = "btxauthorfield",
    actions   = btxauthorfield,
    arguments = { "integer", "string" }
}

implement {
    name      = "btxauthor",
    actions   = btxauthor,
    arguments = {
        "string",
        "string",
        "string",
        {
            { "combiner" },
            { "kind" },
            { "etallimit" },
            { "etaldisplay" },
            { "etaloption" },
            { "symbol" },
            { "connector" },
        }
    }
}

local function components(snippet,short)
    local vons       = snippet.vons
    local surnames   = snippet.surnames
    local initials   = snippet.initials
    local firstnames = not short and snippet.firstnames
    local juniors    = snippet.juniors
    return
        vons       and #vons       > 0 and concat(vons," ") or "",
        surnames   and #surnames   > 0 and concat(surnames," ") or "",
        initials   and #initials   > 0 and concat(the_initials(initials)," ") or "",
        firstnames and #firstnames > 0 and concat(firstnames," ") or "",
        juniors    and #juniors    > 0 and concat(juniors, " ") or ""
end

local collapsers = allocate { }

publications.authorcollapsers = collapsers

-- making a constructor doesn't make the code nicer as the_initials is an
-- exception

local function default(author) -- one author
    local hash = author.hash
    if hash then
        return hash
    end
    local original   = author.original
    local vons       = author.vons
    local surnames   = author.surnames
    local initials   = author.initials
    local firstnames = author.firstnames
    local juniors    = author.juniors
    local result     = { }
    local nofresult  = 0
    if vons and #vons > 0 then
        for j=1,#vons do
            nofresult = nofresult + 1
            result[nofresult] = vons[j]
        end
    end
    if surnames and #surnames > 0 then
        for j=1,#surnames do
            nofresult = nofresult + 1
            result[nofresult] = surnames[j]
        end
    end
    if initials and #initials > 0 then
        initials = the_initials(initials)
        for j=1,#initials do
            nofresult = nofresult + 1
            result[nofresult] = initials[j]
        end
    end
    if firstnames and #firstnames > 0 then
        for j=1,#firstnames do
            nofresult = nofresult + 1
            result[nofresult] = firstnames[j]
        end
    end
    if juniors and #juniors > 0 then
        for j=1,#juniors do
            nofresult = nofresult + 1
            result[nofresult] = juniors[j]
        end
    end
    local hash = concat(result," ")
    if trace_hashing then
        report("hash: %s -> %s",original,hash)
    end
    author.hash = hash
    return hash
end

local authorhashers        = { }
publications.authorhashers = authorhashers

-- todo: some hashing

local function name(authors)
    if type(authors) == "table" then
        local n = #authors
        if n == 0 then
            return ""
        end
        local result    = { }
        local nofresult = 0
        for i=1,n do
            local author   = authors[i]
            local surnames = author.surnames
            if surnames and #surnames > 0 then
                for j=1,#surnames do
                    nofresult = nofresult + 1
                    result[nofresult] = surnames[j]
                end
            end
        end
        return concat(result," ")
    else
        return authors
    end
end

table.setmetatableindex(authorhashers,function(t,k)
    t[k] = name
    return name
end)

authorhashers.normal = function(authors)
    if type(authors) == "table" then
        local n = #authors
        if n == 0 then
            return ""
        end
        local result    = { }
        local nofresult = 0
        for i=1,n do
            local author     = authors[i]
            local vons       = author.vons
            local surnames   = author.surnames
            local firstnames = author.firstnames
            local juniors    = author.juniors
            if vons and #vons > 0 then
                for j=1,#vons do
                    nofresult = nofresult + 1
                    result[nofresult] = vons[j]
                end
            end
            if surnames and #surnames > 0 then
                for j=1,#surnames do
                    nofresult = nofresult + 1
                    result[nofresult] = surnames[j]
                end
            end
            if firstnames and #firstnames > 0 then
                for j=1,#firstnames do
                    nofresult = nofresult + 1
                    result[nofresult] = firstnames[j]
                end
            end
            if juniors and #juniors > 0 then
                for j=1,#juniors do
                    nofresult = nofresult + 1
                    result[nofresult] = juniors[j]
                end
            end
        end
        return concat(result," ")
    else
        return authors
    end
end

authorhashers.normalshort = function(authors)
    if type(authors) == "table" then
        local n = #authors
        if n == 0 then
            return ""
        end
        local result    = { }
        local nofresult = 0
        for i=1,n do
            local author   = authors[i]
            local vons     = author.vons
            local surnames = author.surnames
            local initials = author.initials
            local juniors  = author.juniors
            if vons and #vons > 0 then
                for j=1,#vons do
                    nofresult = nofresult + 1
                    result[nofresult] = vons[j]
                end
            end
            if surnames and #surnames > 0 then
                for j=1,#surnames do
                    nofresult = nofresult + 1
                    result[nofresult] = surnames[j]
                end
            end
            if initials and #initials > 0 then
                initials = the_initials(initials)
                for j=1,#initials do
                    nofresult = nofresult + 1
                    result[nofresult] = initials[j]
                end
            end
            if juniors and #juniors > 0 then
                for j=1,#juniors do
                    nofresult = nofresult + 1
                    result[nofresult] = juniors[j]
                end
            end
        end
        return concat(result," ")
    else
        return authors
    end
end

local sequentialhash = function(authors)
    if type(authors) == "table" then
        local n = #authors
        if n == 0 then
            return ""
        end
        local result    = { }
        local nofresult = 0
        for i=1,n do
            local author     = authors[i]
            local vons       = author.vons
            local surnames   = author.surnames
            local firstnames = author.firstnames
            local juniors    = author.juniors
            if firstnames and #firstnames > 0 then
                for j=1,#firstnames do
                    nofresult = nofresult + 1
                    result[nofresult] = firstnames[j]
                end
            end
            if vons and #vons > 0 then
                for j=1,#vons do
                    nofresult = nofresult + 1
                    result[nofresult] = vons[j]
                end
            end
            if surnames and #surnames > 0 then
                for j=1,#surnames do
                    nofresult = nofresult + 1
                    result[nofresult] = surnames[j]
                end
            end
            if juniors and #juniors > 0 then
                for j=1,#juniors do
                    nofresult = nofresult + 1
                    result[nofresult] = juniors[j]
                end
            end
        end
        return concat(result," ")
    else
        return authors
    end
end

local sequentialshorthash = function(authors)
    if type(authors) == "table" then
        local n = #authors
        if n == 0 then
            return ""
        end
        local result    = { }
        local nofresult = 0
        for i=1,n do
            local author   = authors[i]
            local vons     = author.vons
            local surnames = author.surnames
            local initials = author.initials
            local juniors  = author.juniors
            if initials and #initials > 0 then
                initials = the_initials(initials)
                for j=1,#initials do
                    nofresult = nofresult + 1
                    result[nofresult] = initials[j]
                end
            end
            if vons and #vons > 0 then
                for j=1,#vons do
                    nofresult = nofresult + 1
                    result[nofresult] = vons[j]
                end
            end
            if surnames and #surnames > 0 then
                for j=1,#surnames do
                    nofresult = nofresult + 1
                    result[nofresult] = surnames[j]
                end
            end
            if juniors and #juniors > 0 then
                for j=1,#juniors do
                    nofresult = nofresult + 1
                    result[nofresult] = juniors[j]
                end
            end
        end
        return concat(result," ")
    else
        return authors
    end
end

authorhashers.sequential      = sequentialhash
authorhashers.sequentialshort = sequentialshorthash
authorhashers.normalinverted  = authorhashers.normal
authorhashers.invertedshort   = authorhashers.normalshort

local p_clean = Cs ( (
                    P("\\btxcmd") / "" -- better keep the argument
                  + S("`~!@#$%^&*()_-+={}[]:;\"\'<>,.?/|\\") / ""
                  + lpeg.patterns.utf8character
                )^1)

-- Probabbly more robust is a two pass approach.

authorhashers.short = function(authors)
    -- a short is a real dumb hardcoded kind of tag and we only support
    -- this one because some users might expect it, not because it makes
    -- sense
    if type(authors) == "table" then
        local n = #authors
        if n == 0 then
            return "unk"
        elseif n == 1 then
            local surnames = authors[1].surnames
            if not surnames or #surnames == 0 then
                return "err"
            else
                local s = surnames[1]
                local c = lpegmatch(p_clean,s)
                if trace_hashing and s ~= c then
                    report_cite("name %a cleaned to %a for short construction",s,c)
                end
                return utfsub(c,1,3)
            end
        else
            local t = { }
            for i=1,n do
                if i > 3 then
                    t[#t+1] = "+" -- indeed
                    break
                end
                local surnames = authors[i].surnames
                if not surnames or #surnames == 0 then
                    t[#t+1] = "?"
                else
                    local s = surnames[1]
                    local c = lpegmatch(p_clean,s)
                    if s ~= c then
                        report_cite("name %a cleaned to %a for short construction",s,c)
                    end
                    t[#t+1] = utfsub(c,1,1)
                end
            end
            return concat(t)
        end
    else
        return utfsub(authors,1,3)
    end
end

collapsers.default = default

local function authorwriter(key,index)
    if not key then
        return ""
    end
    if type(key) == "string" then
        return key
    end
    local n = #key
    if n == 0 then
        return ""
    end
    if index then
        if not key[index] then
            return ""
        end
    elseif n == 1 then
        index = 1
    end
    if index then
        local author  = key[index]
        local options = author.options
        if options then
            for option in next, options do
                local collapse = collapsers[option]
                if collapse then
                    return collapse(author)
                end
            end
        end
        local hash = default(author)
     -- if trace_hashing then
     --     report("hash: %s",hash)
     -- end
        return hash
    end
    local t = { }
    local s = 0
    for i=1,n do
        local author  = key[i]
        local options = author.options
        s = s + 1
        if options then
            local done = false
            for option in next, options do
                local collapse = collapsers[option]
                if collapse then
                    t[s] = collapse(author)
                    done = true
                end
            end
            if not done then
                t[s] = default(author)
            end
        else
            t[s] = default(author)
        end
    end
    local hash = concat(t," & ")
 -- if trace_hashing then
 --     report("hash: %s",hash)
 -- end
    return hash
end

local function writer(key)
    return authorwriter(key) -- discard extra arguments in the caller
end

publications.writers   .author = writer
publications.casters   .author = splitauthorstring
publications.components.author = components

-- sharedmethods.author = {
--     { field = "key",     default = "",     unknown = "" },
--     { field = "author",  default = "",     unknown = "" },
--     { field = "title",   default = "",     unknown = "" },
-- }

-- Analysis of the APA by Alan:
--
-- first : key author editor publisher title           journal volume number pages
-- second: year suffix                 title month day journal volume number

publications.sortmethods.authoryear = {
    sequence = {
     -- { field = "key",     default = "ZZZZ", unknown = "ZZZZ" },
        { field = "author",  default = "",     unknown = "" },
        { field = "year",    default = "9998", unknown = "9999" },
     -- { field = "suffix",  default = " ",    unknown = " " },
        { field = "month",   default = "13",   unknown = "14" },
        { field = "day",     default = "32",   unknown = "33" },
        { field = "journal", default = "",     unknown = "" },
        { field = "volume",  default = "",     unknown = "" },
     -- { field = "number",  default = "",     unknown = "" },
        { field = "pages",   default = "",     unknown = "" },
        { field = "title",   default = "",     unknown = "" },
        { field = "index",   default = "",     unknown = "" },
    },
}

implement {
    name      = "btxremapauthor",
    arguments = "2 strings",
    actions   = function(k,v)
        local a  = { splitauthor(k,true) }
        local s1 = sequentialhash(a)
        local s2 = sequentialshorthash(a)
        if not authormap[k] then
            authormap[k] = v
            report("%a mapped onto %a",k,v)
        end
        if not authormap[s1] then
            authormap[s1] = v
            report("%a mapped onto %a, derived from %a",s1,v,k)
        end
        if not authormap[s2] then
            authormap[s2] = v
            report("%a mapped onto %a, derived from %a",s2,v,k)
        end
    end
}

implement {
    name      = "btxshowauthorremapping",
    actions   = function(k,v)
        report("start author remapping")
        for k, v in sortedhash(authormap) do
            report(" %s => %s",k,v)
        end
        report("stop author remapping")
    end
}
