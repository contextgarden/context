7if not modules then modules = { } end modules ['publ-ini'] = {
    version   = 1.001,
    comment   = "this module part of publication support",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- bah .. this 200 locals limit again ... so we need to split it as adding more
-- do ... ends makes it messier

-- plug the list sorted in the list mechanism (specification.sortorder)

-- If we define two datasets with the same bib file we can consider
-- sharing the data but that means that we need to have a parent which
-- in turn makes things messy if we start manipulating entries in
-- different ways (future) .. not worth the trouble as we will seldom
-- load big bib files many times and even then ... fonts are larger.

-- A potential optimization is to work with current_dataset, current_tag when
-- fetching fields but the code become real messy that way (many currents). The
-- gain is not that large anyway because not much publication stuff is flushed.

local next, rawget, type, tostring, tonumber = next, rawget, type, tostring, tonumber
local match, find = string.match, string.find
local concat, sort, tohash = table.concat, table.sort, table.tohash
local utfsub = utf.sub
local mod = math.mod
local formatters = string.formatters
local allocate = utilities.storage.allocate
local settings_to_array, settings_to_set = utilities.parsers.settings_to_array, utilities.parsers.settings_to_set
local sortedkeys, sortedhash = table.sortedkeys, table.sortedhash
local setmetatableindex = table.setmetatableindex
local lpegmatch = lpeg.match
local P, S, C, Ct, R, Carg = lpeg.P, lpeg.S, lpeg.C, lpeg.Ct, lpeg.R, lpeg.Carg
local upper = utf.upper

local report             = logs.reporter("publications")
local report_cite        = logs.reporter("publications","cite")
local report_list        = logs.reporter("publications","list")
local report_reference   = logs.reporter("publications","reference")

local trace              = false  trackers.register("publications",                 function(v) trace            = v end)
local trace_cite         = false  trackers.register("publications.cite",            function(v) trace_cite       = v end)
local trace_missing      = false  trackers.register("publications.cite.missing",    function(v) trace_missing    = v end)
local trace_references   = false  trackers.register("publications.cite.references", function(v) trace_references = v end)
local trace_detail       = false  trackers.register("publications.detail",          function(v) trace_detail     = v end)

publications             = publications or { }
local datasets           = publications.datasets
local writers            = publications.writers
local casters            = publications.casters
local detailed           = publications.detailed
local enhancer           = publications.enhancer
local enhancers          = publications.enhancers

local tracers            = publications.tracers or { }
publications.tracers     = tracers

local variables          = interfaces.variables

local v_local            = variables["local"]
local v_global           = variables["global"]

local v_force            = variables.force
local v_none             = variables.none
local v_yes              = variables.yes
local v_all              = variables.all
local v_default          = variables.default
local v_dataset          = variables.dataset

local numbertochar       = converters.characters

local logsnewline        = logs.newline
local logspushtarget     = logs.pushtarget
local logspoptarget      = logs.poptarget

local isdefined          = tex.isdefined

----- basicsorter        = sorters.basicsorter -- (a,b)
----- sortstripper       = sorters.strip
----- sortsplitter       = sorters.splitters.utf

local manipulators       = typesetters.manipulators
local splitmanipulation  = manipulators.splitspecification
local applymanipulation  = manipulators.applyspecification
local manipulatormethods = manipulators.methods

-- this might move elsewhere

manipulatormethods.Word  = converters.Word
manipulatormethods.WORD  = converters.WORD
manipulatormethods.Words = converters.Words
manipulatormethods.WORDS = converters.WORDS

local context                     = context
local commands                    = commands
local implement                   = interfaces.implement
local ctx_setmacro                = interfaces.setmacro

local ctx_doifelse                = commands.doifelse
local ctx_doif                    = commands.doif
local ctx_doifnot                 = commands.doifnot
local ctx_gobbletwoarguments      = context.gobbletwoarguments

local ctx_btxdirectlink           = context.btxdirectlink
local ctx_btxhandlelistentry      = context.btxhandlelistentry
local ctx_btxhandlelisttextentry  = context.btxhandlelisttextentry
local ctx_btxchecklistentry       = context.btxchecklistentry
local ctx_btxchecklistcombi       = context.btxchecklistcombi

local ctx_btxsetdataset           = context.btxsetdataset
local ctx_btxsettag               = context.btxsettag
local ctx_btxsetnumber            = context.btxsetnumber
local ctx_btxsetlanguage          = context.btxsetlanguage
local ctx_btxsetcombis            = context.btxsetcombis
local ctx_btxsetcategory          = context.btxsetcategory
local ctx_btxcitesetup            = context.btxcitesetup
local ctx_btxpagesetup            = context.btxpagesetup
local ctx_btxsetfirst             = context.btxsetfirst
local ctx_btxsetsecond            = context.btxsetsecond
local ctx_btxsetthird             = context.btxsetthird
local ctx_btxsetinternal          = context.btxsetinternal
local ctx_btxsetlefttext          = context.btxsetlefttext
local ctx_btxsetrighttext         = context.btxsetrighttext
local ctx_btxsetbefore            = context.btxsetbefore
local ctx_btxsetafter             = context.btxsetafter
local ctx_btxsetbacklink          = context.btxsetbacklink
local ctx_btxsetbacktrace         = context.btxsetbacktrace
local ctx_btxsetcount             = context.btxsetcount
local ctx_btxsetconcat            = context.btxsetconcat
local ctx_btxsetoveflow           = context.btxsetoverflow
local ctx_btxsetfirstpage         = context.btxsetfirstpage
local ctx_btxsetlastpage          = context.btxsetlastpage
local ctx_btxsetfirstinternal     = context.btxsetfirstinternal
local ctx_btxsetlastinternal      = context.btxsetlastinternal
local ctx_btxstartcite            = context.btxstartcite
local ctx_btxstopcite             = context.btxstopcite
local ctx_btxstartciteauthor      = context.btxstartciteauthor
local ctx_btxstopciteauthor       = context.btxstopciteauthor
local ctx_btxstartsubcite         = context.btxstartsubcite
local ctx_btxstopsubcite          = context.btxstopsubcite
local ctx_btxstartlistentry       = context.btxstartlistentry
local ctx_btxstoplistentry        = context.btxstoplistentry
local ctx_btxlistsetup            = context.btxlistsetup
local ctx_btxflushauthor          = context.btxflushauthor
local ctx_btxsetnoflistentries    = context.btxsetnoflistentries
local ctx_btxsetcurrentlistentry  = context.btxsetcurrentlistentry
local ctx_btxsetcurrentlistindex  = context.btxsetcurrentlistindex

languages.data                    = languages.data       or { }
local data                        = languages.data

local specifications              = publications.specifications
local currentspecification        = specifications[false]
local ignoredfields               = { }
publications.currentspecification = currentspecification

local function setspecification(name)
    currentspecification = specifications[name]
    if trace then
        report("setting specification %a",type(name) == "string" and name or "anything")
    end
    publications.currentspecification = currentspecification
end

publications.setspecification = setspecification

implement {
    name      = "btxsetspecification",
    actions   = setspecification,
    arguments = "string",
}

local optionalspace  = lpeg.patterns.whitespace^0
local prefixsplitter = optionalspace * lpeg.splitat(optionalspace * P("::") * optionalspace)

statistics.register("publications load time", function()
    local publicationsstats = publications.statistics
    local nofbytes = publicationsstats.nofbytes
    if nofbytes > 0 then
        return string.format("%s seconds, %s bytes, %s definitions, %s shortcuts",
            statistics.elapsedtime(publications),
            nofbytes,
            publicationsstats.nofdefinitions or 0,
            publicationsstats.nofshortcuts or 0
        )
    else
        return nil
    end
end)

luatex.registerstopactions(function()
    local done = false
    for name, dataset in sortedhash(datasets) do
        for command, n in sortedhash(dataset.commands) do
            if not done then
                logspushtarget("logfile")
                logsnewline()
                report("start used btx commands")
                logsnewline()
                done = true
            end
            if isdefined[command] then
                report("%-20s %-20s % 5i %s",name,command,n,"known")
            elseif isdefined[upper(command)] then
                report("%-20s %-20s % 5i %s",name,command,n,"KNOWN")
            else
                report("%-20s %-20s % 5i %s",name,command,n,"unknown")
            end
        end
    end
    if done then
        logsnewline()
        report("stop used btx commands")
        logsnewline()
        logspoptarget()
    end
end)

-- multipass, we need to sort because hashing is random per run and not per
-- version (not the best changed feature of lua)

local collected = allocate()
local tobesaved = allocate()

do

    local function serialize(t)
        local f_key_table  = formatters[" [%q] = {"]
        local f_key_string = formatters["  %s = %q,"]
        local r = { "return {" }
        local m = 1
        for tag, entry in sortedhash(t) do
            m = m + 1
            r[m] = f_key_table(tag)
            local s = sortedkeys(entry)
            for i=1,#s do
                local k = s[i]
                m = m + 1
                r[m] = f_key_string(k,entry[k])
            end
            m = m + 1
            r[m] = " },"
        end
        r[m] = "}"
        return concat(r,"\n")
    end

    local function finalizer()
        local prefix = tex.jobname -- or environment.jobname
        local setnames = sortedkeys(datasets)
        for i=1,#setnames do
            local name     = setnames[i]
            local dataset  = datasets[name]
            local userdata = dataset.userdata
            local checksum = nil
            local username = file.addsuffix(file.robustname(formatters["%s-btx-%s"](prefix,name)),"lua")
            if userdata and next(userdata) then
                if job.passes.first then
                    local newdata = serialize(userdata)
                    checksum = md5.HEX(newdata)
                    io.savedata(username,newdata)
                end
            else
                os.remove(username)
                username = nil
            end
            local loaded  = dataset.loaded
            local sources = dataset.sources
            local used    = { }
            for i=1,#sources do
                local source = sources[i]
             -- if loaded[source.filename] ~= "previous" then -- needs checking
                if loaded[source.filename] ~= "previous" or loaded[source.filename] == "current" then
                    used[#used+1] = source
                end
            end
            tobesaved[name] = {
                usersource = {
                    filename = username,
                    checksum = checksum,
                },
                datasources = used,
            }
        end
    end

    local function initializer()
        statistics.starttiming(publications)
        for name, state in next, collected do
            local dataset     = datasets[name]
            local datasources = state.datasources
            local usersource  = state.usersource
            if datasources then
                for i=1,#datasources do
                    local filename = datasources[i].filename
                    publications.load {
                        dataset  = dataset,
                        filename = filename,
                        kind     = "previous"
                    }
                end
            end
            if usersource then
                dataset.userdata = table.load(usersource.filename) or { }
            end
        end
        statistics.stoptiming(publications)
        function initializer() end -- will go, for now, runtime loaded
    end

    job.register('publications.collected',tobesaved,initializer,finalizer)

end

-- we want to minimize references as there can be many (at least
-- when testing)

local nofcitations = 0
local usedentries  = nil
local citetolist   = nil
local listtocite   = nil

do

    local initialize = nil

    initialize = function(t)
        usedentries = allocate { }
        citetolist  = allocate { }
        listtocite  = allocate { }
        local names     = { }
        local internals = structures.references.internals
        local p_collect = (C(R("09")^1) * Carg(1) / function(s,entry) listtocite[tonumber(s)] = entry end + P(1))^0
        local nofunique = 0
        local nofreused = 0
        for i=1,#internals do
            local entry = internals[i]
            if entry then
                local metadata = entry.metadata
                if metadata then
                    local kind = metadata.kind
                    if kind == "full" then
                        -- reference (in list)
                        local userdata = entry.userdata
                        if userdata then
                            local tag = userdata.btxref
                            if tag then
                                local set = userdata.btxset or v_default
                                local s = usedentries[set]
                                if s then
                                    local u = s[tag]
                                    if u then
                                        u[#u+1] = entry
                                    else
                                        s[tag] = { entry }
                                    end
                                    nofreused = nofreused + 1
                                else
                                    usedentries[set] = { [tag] = { entry } }
                                    nofunique = nofunique + 1
                                end
                                -- alternative: collect prev in group
                                local bck = userdata.btxbck
                                if bck then
                                    lpegmatch(p_collect,bck,1,entry) -- for s in string.gmatch(bck,"[^ ]+") do listtocite[tonumber(s)] = entry end
                                else
                                    local int = tonumber(userdata.btxint)
                                    if int then
                                        listtocite[int] = entry
                                    end
                                end
                                local detail = datasets[set].details[tag]
-- todo: these have to be pluggable
                                if detail then
                                    local author = detail.author
                                    if author then
                                        for i=1,#author do
                                            local a = author[i]
                                            local s = a.surnames
                                            if s then
                                                local c = concat(s,"+")
                                                local n = names[c]
                                                if n then
                                                    n[#n+1] = a
                                                    break
                                                else
                                                    names[c] = { a }
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    elseif kind == "userdata" then
                        -- list entry (each cite)
                        local userdata = entry.userdata
                        if userdata then
                            local int = tonumber(userdata.btxint)
                            if int then
                                citetolist[int] = entry
                            end
                        end
                    end
                end
            else
                -- weird
            end
        end
        for k, v in next, names do
            local n = #v
            if n > 1 then
                local original = v[1].original
                for i=2,n do
                    if original ~= v[i].original then
                        report("potential clash in name %a",k)
                        for i=1,n do
                            v[i].state = 1
                        end
                        break
                    end
                end
            end
        end
        if trace_detail then
            report("%s unique bibentries: %s reused entries",nofunique,nofreused)
        end
        initialize = nil
    end

    usedentries = setmetatableindex(function(_,k) if initialize then initialize() end return usedentries[k] end)
    citetolist  = setmetatableindex(function(_,k) if initialize then initialize() end return citetolist [k] end)
    listtocite  = setmetatableindex(function(_,k) if initialize then initialize() end return listtocite [k] end)

    function publications.usedentries()
        if initialize then
            initialize()
        end
        return usedentries
    end

end

-- match:
--
-- [current|previous|following] section
-- [current|previous|following] block
-- [current|previous|following] component
--
-- by prefix
-- by dataset

local findallused do

    local reported = { }
    local finder   = publications.finder

    findallused = function(dataset,reference,internal)
        local current = datasets[dataset]
        local finder  = publications.finder -- for the moment, not yet in all betas
        local find    = finder and finder(current,reference)
        local tags    = not find and settings_to_array(reference)
        local todo    = { }
        local okay    = { } -- only if mark
        local set     = usedentries[dataset]
        local valid   = current.luadata
        local ordered = current.ordered
        if set then
            local registered = { }
            local function register(tag)
                if registered[tag] then
                    return
                else
                    registered[tag] = true
                end
                local entry = set[tag]
                if entry then
                    -- only once in a list but at some point we can have more (if we
                    -- decide to duplicate)
                    if #entry == 1 then
                        entry = entry[1]
                    else
                        -- same block and section
                        local done = false
                        if internal and internal > 0 then
                            -- first following in list
                            for i=1,#entry do
                                local e = entry[i]
                                if e.references.internal > internal then
                                    done = e
                                    break
                                end
                            end
                            if not done then
                                -- last preceding in list
                                for i=1,#entry do
                                    local e = entry[i]
                                    if e.references.internal < internal then
                                        done = e
                                    else
                                        break
                                    end
                                end
                            end
                        end
                        if done then
                            entry = done
                        else
                            entry = entry[1]
                        end
                    end
                    okay[#okay+1] = entry
                end
                todo[tag] = true
            end
            if reference == "*" then
                tags = { }
                for i=1,#ordered do
                    local tag = ordered[i].tag
                    register(tag)
                    tags[#tags+1] = tag
                end
            elseif find then
                tags = { }
                for i=1,#ordered do
                    local entry = ordered[i]
                    if find(entry) then
                        local tag = entry.tag
                        register(tag)
                        tags[#tags+1] = tag
                    end
                end
                if #tags == 0 and not reported[reference] then
                    tags[1] = reference
                    reported[reference] = true
                end
            else
                for i=1,#tags do
                    local tag  = tags[i]
                    if valid[tag] then
                        register(tag)
                    elseif not reported[tag] then
                        reported[tag] = true
                        report_cite("non-existent entry %a in %a",tag,dataset)
                    end
                end
            end
        else
            if find then
                tags = { }
                for i=1,#ordered do
                    local entry = ordered[i]
                    if find(entry) then
                        local tag = entry.tag
                        tags[#tags+1] = tag
                        todo[tag] = true
                    end
                end
                if #tags == 0 and not reported[reference] then
                    tags[1] = reference
                    reported[reference] = true
                end
            else
                for i=1,#tags do
                    local tag = tags[i]
                    if valid[tag] then
                        todo[tag] = true
                    elseif not reported[tag] then
                        reported[tag] = true
                        report_cite("non-existent entry %a in %a",tag,dataset)
                    end
                end
            end
        end
        return okay, todo, tags
    end

end

local function unknowncite(reference)
    ctx_btxsettag(reference)
    if trace_detail then
        report("expanding %a cite setup %a","unknown","unknown")
    end
    ctx_btxcitesetup("unknown")
end

local concatstate = publications.concatstate

local tobemarked = nil

local function marknocite(dataset,tag,nofcitations,setup)
    ctx_btxstartcite()
    ctx_btxsetdataset(dataset)
    ctx_btxsettag(tag)
    ctx_btxsetbacklink(nofcitations)
    if trace_detail then
        report("expanding cite setup %a",setup)
    end
    ctx_btxcitesetup(setup)
    ctx_btxstopcite()
end

local function markcite(dataset,tag,flush)
    if not tobemarked then
        return 0
    end
    local citation = tobemarked[tag]
    if not citation then
        return 0
    end
    if citation == true then
        nofcitations = nofcitations + 1
        if trace_cite then
            report_cite("mark, dataset: %s, tag: %s, number: %s, state: %s",dataset,tag,nofcitations,"cited")
        end
        if flush then
            marknocite(dataset,tag,nofcitations,"nocite")
        end
        tobemarked[tag] = nofcitations
        return nofcitations
    else
        return citation
    end
end

local marked_dataset = nil
local marked_list    = nil

local function flushmarked(dataset,list,todo)
    marked_dataset = dataset
    marked_list    = list
end

local function btxflushmarked()
    if marked_list and tobemarked then
        for i=1,#marked_list do
            -- keep order
            local tag = marked_list[i]
            local tbm = tobemarked[tag]
            if tbm == true or not tbm then
                nofcitations = nofcitations + 1
                marknocite(marked_dataset,tag,nofcitations,tbm and "nocite" or "invalid")
                if trace_cite then
                    report_cite("mark, dataset: %s, tag: %s, number: %s, state: %s",marked_dataset,tag,nofcitations,tbm and "unset" or "invalid")
                end
            end
        end
    end
    tobemarked     = nil
    marked_dataset = nil
    marked_list    = nil
end

implement { name = "btxflushmarked", actions = btxflushmarked }

-- basic access

local function getfield(dataset,tag,name) -- for the moment quick and dirty
    local d = datasets[dataset].luadata[tag]
    return d and d[name]
end

local function getdetail(dataset,tag,name) -- for the moment quick and dirty
    local d = datasets[dataset].details[tag]
    return d and d[name]
end

local function getcasted(dataset,tag,field,specification)
    local current = datasets[dataset]
    if current then
        local data = current.luadata[tag]
        if data then
            local category = data.category
            if not specification then
                specification = currentspecification
            end
            local catspec = specification.categories[category]
            if not catspec then
                return false
            end
            local fields = catspec.fields
            if fields then
                local sets = catspec.sets
                if sets then
                    local set = sets[field]
                    if set then
                        for i=1,#set do
                            local field = set[i]
                            local value = fields[field] and data[field] -- redundant check
                            if value then
                                local kind = specification.types[field]
                                return detailed[kind][value], field, kind
                            end
                        end
                    end
                end
                local value = fields[field] and data[field] -- redundant check
                if value then
                    local kind = specification.types[field]
                    return detailed[kind][value], field, kind
                end
            end
            local data = current.details[tag]
            if data then
                local kind = specification.types[field]
                return data[field], field, kind -- no check
            end
        end
    end
end

local function getfaster(current,data,details,field,categories,types)
    local category = data.category
    local catspec  = categories[category]
    if not catspec then
        return false
    end
    local fields = catspec.fields
    if fields then
        local sets = catspec.sets
        if sets then
            local set = sets[field]
            if set then
                for i=1,#set do
                    local field = set[i]
                    local value = fields[field] and data[field] -- redundant check
                    if value then
                        local kind = types[field]
                        return detailed[kind][value], field, kind
                    end
                end
            end
        end
        local value = fields[field] and data[field] -- redundant check
        if value then
            local kind = types[field]
            return detailed[kind][value]
        end
    end
    if details then
        local kind = types[field]
        return details[field]
    end
end

local function getdirect(dataset,data,field,catspec) -- no field check, no dataset check
    local catspec = (catspec or currentspecification).categories[data.category]
    if not catspec then
        return false
    end
    local fields = catspec.fields
    if fields then
        local sets = catspec.sets
        if sets then
            local set = sets[field]
            if set then
                for i=1,#set do
                    local field = set[i]
                    local value = fields[field] and data[field] -- redundant check
                    if value then
                        return value
                    end
                end
            end
        end
        return fields[field] and data[field] or nil -- redundant check
    end
end

local function getfuzzy(data,field,categories) -- no field check, no dataset check
    local catspec
    if categories then
        local category = data.category
        if category then
            catspec = categories[data.category]
        end
    end
    if not field then
        return
    elseif not catspec then
        return data[field]
    end
    local fields = catspec.fields
    if fields then
        local sets = catspec.sets
        if sets then
            local set = sets[field]
            if set then
                for i=1,#set do
                    local field = set[i]
                    local value = fields[field] and data[field] -- redundant check
                    if value then
                        return value
                    end
                end
            end
        end
        return fields[field] and data[field] or nil -- redundant check
    end
end

publications.getfield  = getfield
publications.getdetail = getdetail
publications.getcasted = getcasted
publications.getfaster = getfaster
publications.getdirect = getdirect
publications.getfuzzy  = getfuzzy

-- this needs to be checked: a specific type should have a checker

-- author pagenumber keyword url

-- function commands.btxsingularorplural(dataset,tag,name)
--     local d = getcasted(dataset,tag,name)
--     if type(d) == "table" then
--         d = #d <= 1
--     else
--         d = true
--     end
--     ctx_doifelse(d)
-- end

-- function commands.oneorrange(dataset,tag,name)
--     local d = datasets[dataset].luadata[tag] -- details ?
--     if d then
--         d = d[name]
--     end
--     if type(d) == "string" then
--         d = find(d,"%-")
--     else
--         d = false
--     end
--     ctx_doifelse(not d) -- so singular is default
-- end

-- function commands.firstofrange(dataset,tag,name)
--     local d = datasets[dataset].luadata[tag] -- details ?
--     if d then
--         d = d[name]
--     end
--     if type(d) == "string" then
--         context(match(d,"([^%-]+)"))
--     end
-- end

local inspectors   = allocate()
local nofmultiple  = allocate()
local firstandlast = allocate()

publications.inspectors = inspectors
inspectors.nofmultiple  = nofmultiple
inspectors.firstandlast = firstandlast

function nofmultiple.author(d)
    return type(d) == "table" and #d or 0
end

function publications.singularorplural(dataset,tag,name)
    local data, field, kind = getcasted(dataset,tag,name)
    if data then
        local test = nofmultiple[kind]
        if test then
            local n = test(data)
            return not n or n < 2
        end
    end
    return true
end

function firstandlast.range(d)
    if type(d) == "table" then
        return d[1], d[2]
    end
end

firstandlast.pagenumber = firstandlast.range

function publications.oneorrange(dataset,tag,name)
    local data, field, kind = getcasted(dataset,tag,name)
    if data then
        local test = firstandlast[kind]
        if test then
            local first, last = test(data)
            return not (first and last)
        end
    end
    return nil -- nothing at all
end

function publications.firstofrange(dataset,tag,name)
    local data, field, kind = getcasted(dataset,tag,name)
    if data then
        local test = firstandlast[kind]
        if test then
            local first = test(data)
            if first then
                return first
            end
        end
    end
end

function publications.lastofrange(dataset,tag,name)
    local data, field, kind = getcasted(dataset,tag,name)
    if data then
        local test = firstandlast[kind]
        if test then
            local first, last = test(data)
            if last then
                return last
            end
        end
    end
end

local three_strings = { "string", "string", "string" }

implement {
    name      = "btxsingularorplural",
    actions   = { publications.singularorplural, ctx_doifelse },
    arguments = three_strings
}

implement {
    name      = "btxoneorrange",
    actions   = { publications.oneorrange, function(b) if b == nil then ctx_gobbletwoarguments() else ctx_doifelse(b) end end },
    arguments = three_strings
}

implement {
    name      = "btxfirstofrange",
    actions   = { publications.firstofrange, context },
    arguments = three_strings
}

implement {
    name      = "btxlastofrange",
    actions   = { publications.lastofrange, context },
    arguments = three_strings
}

-- basic loading

function publications.usedataset(specification)
    specification.kind = "current"
    publications.load(specification)
end

implement {
    name      = "btxusedataset",
    actions   = publications.usedataset,
    arguments = {
        {
            { "specification" },
            { "dataset" },
            { "filename" },
        }
    }
}

function commands.convertbtxdatasettoxml(name,nice)
    publications.converttoxml(name,nice)
end

-- enhancing

do

    -- maybe not redo when already done

    local function shortsorter(a,b)
        local ay, by = a[2], b[2]
        if ay ~= by then
            return ay < by
        end
        local ay, by = a[3], b[3]
        if ay ~= by then
            return ay < by
        end
        return a[4] < b[4]
    end

    -- We could avoid loops by combining enhancers but that makes it only
    -- more messy and for documents that use publications the few extra milli
    -- seconds are irrelevant (there is for sure more to gain by proper coding
    -- of the source and or style).

    local f_short = formatters["%t%02i"]

    function publications.enhancers.suffixes(dataset)
        if not dataset then
            return -- bad news
        else
            report("analyzing previous publication run for %a",dataset.name)
        end
        local used = usedentries[dataset.name]
        if not used then
            return -- probably a first run
        end
        local luadata  = dataset.luadata
        local details  = dataset.details
        local ordered  = dataset.ordered
        if not luadata or not details or not ordered then
            report("nothing to be analyzed in %a",dataset.name)
            return -- also bad news
        end
        local field  = "author"  -- currently only author
        local shorts = { }
        for i=1,#ordered do
            local entry = ordered[i]
            if entry then
                local tag = entry.tag
                if tag  then
                    local use = used[tag]
                    if use then
                        -- use is a table of used list entries (so there can be more) and we just look at
                        -- the first one for btx properties
                        local listentry = use[1]
                        local userdata  = listentry.userdata
                        local btxspc    = userdata and userdata.btxspc
                        if btxspc then
                            -- this will become a specification entry
                            local author = getcasted(dataset,tag,field,specifications[btxspc])
                            if type(author) == "table" then
                                -- number depends on sort order
                                local t = { }
                                if #author > 0 then
                                    local n = #author == 1 and 3 or 1
                                    for i=1,#author do
                                        local surnames = author[i].surnames
                                        if not surnames or #surnames == 0 then
                                            -- error
                                        else
                                            t[#t+1] = utfsub(surnames[1],1,n)
                                        end
                                    end
                                end
                                local year  = tonumber(entry.year) or 0
                                local short = f_short(t,mod(year,100))
                                local s = shorts[short]
                                -- we could also sort on reference i.e. entries.text
                                if u then
                                    u = listentry.entries.text -- hm
                                else
                                    u = "0"
                                end
                                if not s then
                                    shorts[short] = { { tag, year, u, i } }
                                else
                                    s[#s+1] = { tag, year, u, i }
                                end
                            else
                                report("author typecast expected for field %a",field)
                            end
                        else
                            --- no spec so let's forget about it
                        end
                    end
                end
            end
        end
        for short, tags in next, shorts do -- ordered ?
            local done = #tags > 0
            -- now we assign the suffixes, unless we have only one reference
            if done then
                sort(tags,shortsorter)
                local n = #tags
                if n > 1 then
                    for i=1,n do
                        local tag     = tags[i][1]
                        local detail  = details[tag]
                        local suffix  = numbertochar(i)
                        local entry   = luadata[tag]
                        local year    = entry.year
                        detail.short  = short
                        detail.suffix = suffix
                        if year then
                            detail.suffixedyear = year .. suffix
                        end
                    end
                end
            else
                local tag    = tags[1][1]
                local detail = details[tag]
                local entry  = luadata[tag]
                local year   = entry.year
                detail.short = short
                if year then
                    detail.suffixedyear = year
                end
            end
        end
    end

    utilities.sequencers.appendaction(enhancer,"system","publications.enhancers.suffixes")

end

implement {
    name      = "btxaddentry",
    actions   = function(name,settings,content)
        local dataset = datasets[name]
        if dataset then
            publications.addtexentry(dataset,settings,content)
        end
    end,
    arguments = { "string",  "string",  "string" }
}

function publications.checkeddataset(name,default)
    local dataset = rawget(datasets,name)
    if dataset then
        return name
    elseif default and default ~= "" then
        return default
    else
        report("unknown dataset %a, forcing %a",name,v_default)
        return v_default
    end
end

implement {
    name      = "btxsetdataset",
    actions   = { publications.checkeddataset, context },
    arguments = { "string", "string"}
}

implement {
    name      = "btxsetentry",
    actions   = function(name,tag)
        local dataset = rawget(datasets,name)
        if dataset then
            if dataset.luadata[tag] then
                context(tag)
            else
                report("unknown tag %a in dataset %a",tag,name)
            end
        else
            report("unknown dataset %a",name)
        end
    end,
    arguments = { "string", "string" },
}

-- rendering of fields

do

    local typesetters        = { }
    publications.typesetters = typesetters

    local function defaulttypesetter(field,value,manipulator)
        if value and value ~= "" then
            value = tostring(value)
            context(manipulator and applymanipulation(manipulator,value) or value)
        end
    end

    setmetatableindex(typesetters,function(t,k)
        local v = defaulttypesetter
        t[k] = v
        return v
    end)

    function typesetters.string(field,value,manipulator)
        if value and value ~= "" then
            context(manipulator and applymanipulation(manipulator,value) or value)
        end
    end

    function typesetters.author(field,value,manipulator)
        ctx_btxflushauthor(field)
    end

 -- function typesetters.url(field,value,manipulator)
 --     ....
 -- end

    -- if there is no specification then we're in trouble but there is
    -- always a default anyway
    --
    -- there's also always a fields table but it can be empty due to
    -- lack of specifications
    --
    -- then there can be cases where we have no specification for instance
    -- when we have a special kind of database

    local splitter = lpeg.splitat(":")

    local function permitted(category,field)
        local catspec = currentspecification.categories[category]
        if not catspec then
            report("invalid category %a, %s",category,"no specification") -- can't happen
            return false
        end
        local fields = catspec.fields
        if not fields then
            report("invalid category %a, %s",category,"no fields") -- can't happen
            return false
        end
        if ignoredfields and ignoredfields[field] then
            return false
        end
        local virtual = catspec.virtual
        if virtual and virtual[field] then
            return true
        end
        local sets = catspec.sets
        if sets then
            local set = sets[field]
            if set then
                return set
            end
        end
        if fields[field] then
            return true
        end
        local f, l = lpegmatch(splitter,field)
        if f and l and fields[f] then
            return true -- language specific one
        end
    end

    local function found(dataset,tag,field,valid,fields)
        if valid == true then
         -- local fields = dataset.luadata[tag]
            local okay = fields[field]
            if okay then
                return field, okay
            end
            local details = dataset.details[tag]
            local value = details[field]
            if value then
                return field, value
            end
        elseif valid then
         -- local fields = dataset.luadata[tag]
            for i=1,#valid do
                local field = valid[i]
                local value = fields[field]
                if value then
                    return field, value
                end
            end
            local details = dataset.details[tag]
            for i=1,#valid do
                local value = details[field]
                if value then
                    return field, value
                end
            end
        end
    end

    local function get(dataset,tag,field,what,check,catspec) -- somewhat more extensive
        local current = rawget(datasets,dataset)
        if current then
            local data = current.luadata[tag]
            if data then
                local category = data.category
                local catspec  = (catspec or currentspecification).categories[category]
                if not catspec then
                    return false
                end
                local fields = catspec.fields
                if fields then
                    local sets = catspec.sets
                    if sets then
                        local set = sets[field]
                        if set then
                            if check then
                                for i=1,#set do
                                    local field = set[i]
                                    local kind  = (not check or data[field]) and fields[field]
                                    if kind then
                                        return what and kind or field
                                    end
                                end
                            elseif what then
                                local t = { }
                                for i=1,#set do
                                    t[i] = fields[set[i]] or "unknown"
                                end
                                return concat(t,",")
                            else
                                return concat(set,",")
                            end
                        end
                    end
                    local kind = (not check or data[field]) and fields[field]
                    if kind then
                        return what and kind or field
                    end
                end
            end
        end
        return ""
    end

    publications.permitted = permitted
    publications.found     = found
    publications.get       = get

    local function btxflush(name,tag,field)
        local dataset = rawget(datasets,name)
        if dataset then
            local fields = dataset.luadata[tag]
            if fields then
                local manipulator, field = splitmanipulation(field)
                local category = fields.category
                local valid    = permitted(category,field)
                if valid then
                    local name, value = found(dataset,tag,field,valid,fields)
                    if value then
                        typesetters[currentspecification.types[name]](field,value,manipulator)
                    elseif trace_detail then
                        report("%s %s %a in category %a for tag %a in dataset %a","unknown","entry",field,category,tag,name)
                    end
                elseif trace_detail then
                    report("%s %s %a in category %a for tag %a in dataset %a","invalid","entry",field,category,tag,name)
                end
            else
                report("unknown tag %a in dataset %a",tag,name)
            end
        else
            report("unknown dataset %a",name)
        end
    end

    local function btxfield(name,tag,field)
        local dataset = rawget(datasets,name)
        if dataset then
            local fields = dataset.luadata[tag]
            if fields then
                local category = fields.category
                local manipulator, field = splitmanipulation(field)
                if permitted(category,field) then
                    local value = fields[field]
                    if value then
                        typesetters[currentspecification.types[field]](field,value,manipulator)
                    elseif trace_detail then
                        report("%s %s %a in category %a for tag %a in dataset %a","unknown","field",field,category,tag,name)
                    end
                elseif trace_detail then
                    report("%s %s %a in category %a for tag %a in dataset %a","invalid","field",field,category,tag,name)
                end
            else
                report("unknown tag %a in dataset %a",tag,name)
            end
        else
            report("unknown dataset %a",name)
        end
    end

    local function btxdetail(name,tag,field)
        local dataset = rawget(datasets,name)
        if dataset then
            local fields = dataset.luadata[tag]
            if fields then
                local details = dataset.details[tag]
                if details then
                    local category = fields.category
                    local manipulator, field = splitmanipulation(field)
                    if permitted(category,field) then
                        local value = details[field]
                        if value then
                            typesetters[currentspecification.types[field]](field,value,manipulator)
                        elseif trace_detail then
                            report("%s %s %a in category %a for tag %a in dataset %a","unknown","detail",field,category,tag,name)
                        end
                    elseif trace_detail then
                        report("%s %s %a in category %a for tag %a in dataset %a","invalid","detail",field,category,tag,name)
                    end
                else
                    report("no details for tag %a in dataset %a",tag,name)
                end
            else
                report("unknown tag %a in dataset %a",tag,name)
            end
        else
            report("unknown dataset %a",name)
        end
    end

    local function btxdirect(name,tag,field)
        local dataset = rawget(datasets,name)
        if dataset then
            local fields = dataset.luadata[tag]
            if fields then
                local manipulator, field = splitmanipulation(field)
                local value = fields[field]
                if value then
                    context(typesetters.default(field,value,manipulator))
                elseif trace_detail then
                    report("field %a of tag %a in dataset %a has no value",field,tag,name)
                end
            else
                report("unknown tag %a in dataset %a",tag,name)
            end
        else
            report("unknown dataset %a",name)
        end
    end

    local function okay(name,tag,field)
        local dataset = rawget(datasets,name)
        if dataset then
            local fields = dataset.luadata[tag]
            if fields then
                local category = fields.category
                local valid    = permitted(category,field)
                if valid then
                    local value, field = found(dataset,tag,field,valid,fields)
                    return value and value ~= ""
                end
            end
        end
    end

    publications.okay = okay

    implement { name = "btxfield",     actions = btxfield,  arguments = { "string", "string", "string" } }
    implement { name = "btxdetail",    actions = btxdetail, arguments = { "string", "string", "string" } }
    implement { name = "btxflush",     actions = btxflush,  arguments = { "string", "string", "string" } }
    implement { name = "btxdirect",    actions = btxdirect, arguments = { "string", "string", "string" } }

    implement { name = "btxfieldname", actions = { get, context }, arguments = { "string", "string", "string", false, false } }
    implement { name = "btxfieldtype", actions = { get, context }, arguments = { "string", "string", "string", true,  false } }
    implement { name = "btxfoundname", actions = { get, context }, arguments = { "string", "string", "string", false, true  } }
    implement { name = "btxfoundtype", actions = { get, context }, arguments = { "string", "string", "string", true,  true  } }

    implement { name = "btxdoifelse",  actions = { okay, ctx_doifelse }, arguments = { "string", "string", "string" } }
    implement { name = "btxdoif",      actions = { okay, ctx_doif     }, arguments = { "string", "string", "string" } }
    implement { name = "btxdoifnot",   actions = { okay, ctx_doifnot  }, arguments = { "string", "string", "string" } }

end

-- -- alternative approach: keep data at the tex end

function publications.singularorplural(singular,plural)
    if lastconcatsize and lastconcatsize > 1 then
        context(plural)
    else
        context(singular)
    end
end

-- loading

do

    local patterns = {
        "publ-imp-%s.mkvi",
        "publ-imp-%s.mkiv",
        "publ-imp-%s.tex",
    }

    local function failure(name)
        report("unknown library %a",name)
    end

    local function action(name,foundname)
        context.input(foundname)
    end

    function publications.loaddefinitionfile(name) -- a more specific name
        commands.uselibrary {
            name     = string.gsub(name,"^publ%-",""),
            patterns = patterns,
            action   = action,
            failure  = failure,
            onlyonce = true,
        }
    end

    local patterns = {
        "publ-imp-%s.lua",
    }

    function publications.loadreplacementfile(name) -- a more specific name
        commands.uselibrary {
            name     = string.gsub(name,"^publ%-",""),
            patterns = patterns,
            action   = publications.loaders.registercleaner,
            failure  = failure,
            onlyonce = true,
        }
    end

    implement { name = "btxloaddefinitionfile",  actions = publications.loaddefinitionfile,  arguments = "string" }
    implement { name = "btxloadreplacementfile", actions = publications.loadreplacementfile, arguments = "string" }

end

-- lists

do

    publications.lists = publications.lists or { }
    local lists        = publications.lists

    local context     = context
    local structures  = structures

    local references  = structures.references
    local sections    = structures.sections

    -- per rendering

    local renderings = { } --- per dataset

    setmetatableindex(renderings,function(t,k)
        local v = {
            list         = { },
            done         = { },
            alldone      = { },
            used         = { },
            registered   = { },
            ordered      = { },
            shorts       = { },
            method       = v_none,
            texts        = setmetatableindex("table"),
            currentindex = 0,
        }
        t[k] = v
        return v
    end)

    -- helper

    function lists.register(dataset,tag,short) -- needs checking now that we split
        local r = renderings[dataset]
        if not short or short == "" then
            short = tag
        end
        if trace then
            report("registering publication entry %a with shortcut %a",tag,short)
        end
        local top = #r.registered + 1
        -- do we really need these
        r.registered[top] = tag
        r.ordered   [tag] = top
        r.shorts    [tag] = short
    end

    function lists.nofregistered(dataset)
        return #renderings[dataset].registered
    end

    local function validkeyword(dataset,tag,keyword,specification) -- todo: pass specification
        local kw = getcasted(dataset,tag,"keywords",specification)
        if kw then
            for i=1,#kw do
                if keyword[kw[i]] then
                    return true
                end
            end
        end
    end

    local function registerpage(pages,tag,result,listindex)
        local p = pages[tag]
        local r = result[listindex].references
        if p then
            local last = p[#p][2]
            local real = last.realpage
            if real ~= r.realpage then
                p[#p+1] = { listindex, r }
            end
        else
            pages[tag] = { { listindex, r } }
        end
    end

    local methods = { }
    lists.methods = methods

    methods[v_dataset] = function(dataset,rendering,keyword)
        -- why only once unless criterium=all?
        local current = datasets[dataset]
        local luadata = current.luadata
        local list    = rendering.list
        for tag, data in sortedhash(luadata) do
            if not keyword or validkeyword(dataset,tag,keyword) then
                list[#list+1] = { tag, false, 0, false, false, data.index or 0}
            end
        end
    end

    -- todo: names = { "btx" }

    methods[v_force] = function (dataset,rendering,keyword)
        -- only for checking, can have duplicates, todo: collapse page numbers, although
        -- we then also needs deferred writes
        local result  = structures.lists.filter(rendering.specifications) or { }
        local list    = rendering.list
        local current = datasets[dataset]
        local luadata = current.luadata
        for listindex=1,#result do
            local r = result[listindex]
            local u = r.userdata
            if u then
                local set = u.btxset or v_default
                if set == dataset then
                    local tag = u.btxref
                    if tag and (not keyword or validkeyword(dataset,tag,keyword)) then
                        local data = luadata[tag]
                        list[#list+1] = { tag, listindex, 0, u, u.btxint, data and data.index or 0 }
                    end
                end
            end
        end
        lists.result = result
    end

    -- local  : if tag and                      done[tag] ~= section then ...
    -- global : if tag and not alldone[tag] and done[tag] ~= section then ...

    methods[v_local] = function(dataset,rendering,keyword)
        local result    = structures.lists.filter(rendering.specifications) or { }
        local section   = sections.currentid()
        local list      = rendering.list
        local repeated  = rendering.repeated == v_yes
        local r_done    = rendering.done
        local r_alldone = rendering.alldone
        local done      = repeated and { } or r_done
        local alldone   = repeated and { } or r_alldone
        local doglobal  = rendering.method == v_global
        local traced    = { } -- todo: only if interactive (backlinks) or when tracing
        local pages     = { }
        local current   = datasets[dataset]
        local luadata   = current.luadata
        -- handy for tracing :
        rendering.result = result
        --
        for listindex=1,#result do
            local r = result[listindex]
            local u = r.userdata
            if u then
                local set = u.btxset or v_default
                if set == dataset then
                    local tag = u.btxref
                    if not tag then
                        -- problem
                    elseif done[tag] == section then -- a bit messy for global and all and so
                        -- skip
                    elseif doglobal and alldone[tag] then
                        -- skip
                    elseif not keyword or validkeyword(dataset,tag,keyword) then
                        if traced then
                            local l = traced[tag]
                            if l then
                                l[#l+1] = u.btxint
                            else
                                local data = luadata[tag]
                                local l = { tag, listindex, 0, u, u.btxint, data and data.index or 0 }
                                list[#list+1] = l
                                traced[tag] = l
                            end
                        else
                            done[tag]    = section
                            alldone[tag] = true
                            local data = luadata[tag]
                            list[#list+1] = { tag, listindex, 0, u, u.btxint, data and data.index or 0 }
                        end
                    end
                    registerpage(pages,tag,result,listindex)
                end
            end
        end
        if traced then
            for tag in next, traced do
                done[tag]    = section
                alldone[tag] = true
            end
        end
        lists.result = result
        structures.lists.result = result
        rendering.pages = pages -- or list.pages
    end

    methods[v_global] = methods[v_local]

    function lists.collectentries(specification)
        local dataset = specification.dataset
        if not dataset then
            return
        end
        local rendering  = renderings[dataset]
        if not rendering then
            return
        end
        local method             = specification.method or v_none
        local ignored            = specification.ignored or ""
        rendering.method         = method
        rendering.ignored        = ignored ~= "" and settings_to_set(ignored) or nil
        rendering.list           = { }
        rendering.done           = { }
        rendering.sorttype       = specification.sorttype or v_default
        rendering.criterium      = specification.criterium or v_none
        rendering.repeated       = specification.repeated or v_no
        rendering.group          = specification.group or ""
        rendering.specifications = specification
        local filtermethod       = methods[method]
        if not filtermethod then
            report_list("invalid method %a",method or "")
            return
        end
        lists.result  = { } -- kind of reset
        local keyword = specification.keyword
        if keyword and keyword ~= "" then
            keyword = settings_to_set(keyword)
        else
            keyword = nil
        end
        filtermethod(dataset,rendering,keyword)
        ctx_btxsetnoflistentries(#rendering.list)
    end

    -- for determining width

    local groups = setmetatableindex("number")

    function lists.prepareentries(dataset)
        local rendering = renderings[dataset]
        local list      = rendering.list
        local used      = rendering.used
        local forceall  = rendering.criterium == v_all
        local repeated  = rendering.repeated == v_yes
        local sorttype  = rendering.sorttype or v_default
        local group     = rendering.group or ""
        local sorter    = lists.sorters[sorttype]
        local current   = datasets[dataset]
        local luadata   = current.luadata
        local details   = current.details
        local newlist   = { }
        local lastreferencenumber = groups[group] -- current.lastreferencenumber or 0
        for i=1,#list do
            local li    = list[i]
            local tag   = li[1]
            local entry = luadata[tag]
            if entry then
                if forceall or repeated or not used[tag] then
                    newlist[#newlist+1] = li
                    -- already here:
                    if not repeated then
                        used[tag] = true -- beware we keep the old state (one can always use criterium=all)
                    end
                    local detail = details[tag]
                    if detail then
                        local referencenumber = detail.referencenumber
                        if not referencenumber then
                            lastreferencenumber    = lastreferencenumber + 1
                            referencenumber        = lastreferencenumber
                            detail.referencenumber = lastreferencenumber
                        end
                        li[3] = referencenumber
                    else
                        report("missing details for tag %a in dataset %a (enhanced: %s)",tag,dataset,current.enhanced and "yes" or "no")
                        -- weird, this shouldn't happen .. all have a detail
                        lastreferencenumber = lastreferencenumber + 1
                        details[tag] = { referencenumber = lastreferencenumber }
                        li[3] = lastreferencenumber
                    end
                end
            end
        end
        groups[group] = lastreferencenumber
        if type(sorter) == "function" then
            rendering.list = sorter(dataset,rendering,newlist,sorttype) or newlist
        else
            rendering.list = newlist
        end
    end

    function lists.fetchentries(dataset)
        local rendering = renderings[dataset]
        local list      = rendering.list
        if list then
            for i=1,#list do
                local li = list[i]
                ctx_btxsettag(li[1])
                ctx_btxsetnumber(li[3])
                ctx_btxchecklistentry()
            end
        end
    end

    -- for rendering

    -- setspecification

    local function btxflushpages(dataset,tag)
        -- todo: interaction
        local rendering = renderings[dataset]
        local pages     = rendering.pages
        if not pages then
            return
        else
            pages = pages[tag]
        end
        if not pages then
            return
        end
        local nofpages = #pages
        if nofpages == 0 then
            return
        end
        local first_p = nil
        local first_r = nil
        local last_p  = nil
        local last_r  = nil
        local ranges  = { }
        local nofdone = 0
        local function flush()
            if last_r and first_r ~= last_r then
                ranges[#ranges+1] = { first_p, last_p }
            else
                ranges[#ranges+1] = { first_p }
            end
        end
        for i=1,nofpages do
            local next_p = pages[i]
            local next_r = next_p[2].realpage
            if not first_r then
                first_p = next_p
                first_r = next_r
            elseif last_r + 1 == next_r then
                -- continue
            elseif first_r then
                flush()
                first_p = next_p
                first_r = next_r
            end
            last_p = next_p
            last_r = next_r
        end
        if first_r then
            flush()
        end
        local nofranges = #ranges
        for i=1,nofranges do
            local r = ranges[i]
            ctx_btxsetconcat(concatstate(i,nofranges))
            local first, last = r[1], r[2]
            ctx_btxsetfirstinternal(first[2].internal)
            ctx_btxsetfirstpage(first[1])
            if last then
                ctx_btxsetlastinternal(last[2].internal)
                ctx_btxsetlastpage(last[1])
            end
            if trace_detail then
                report("expanding page setup")
            end
            ctx_btxpagesetup()
        end
    end

    implement {
        name      = "btxflushpages",
        actions   = btxflushpages,
        arguments = { "string", "string" }
    }

    function lists.sameasprevious(dataset,i,name)
        local rendering = renderings[dataset]
        local list      = rendering.list
        local n         = tonumber(i)
        if n and n > 1 and n <= #list then
            local luadata  = datasets[dataset].luadata
            local current  = getdirect(dataset,luadata[list[n  ][1]],name)
            local previous = getdirect(dataset,luadata[list[n-1][1]],name)
            if trace_detail then
                report("previous %a, current %a",tostring(previous),tostring(current))
            end
            return current and current == previous
        else
            return false
        end
    end

    function lists.flushentry(dataset,i,textmode)
        local rendering = renderings[dataset]
        local list      = rendering.list
        local luadata   = datasets[dataset].luadata
        local li        = list[i]
        if li then
            local tag       = li[1]
            local listindex = li[2]
            local n         = li[3]
            local entry     = luadata[tag]
            --
            ctx_btxstartlistentry()
            ctx_btxsetcurrentlistentry(i) -- redundant
            ctx_btxsetcurrentlistindex(listindex or 0)
            local combined = entry.combined
            local language = entry.language
            if combined then
                ctx_btxsetcombis(concat(combined,","))
            end
            ctx_btxsetcategory(entry.category or "unknown")
            ctx_btxsettag(tag)
            ctx_btxsetnumber(n)
            if language then
                ctx_btxsetlanguage(language)
            end
            local bl = li[5]
            if bl and bl ~= "" then
                ctx_btxsetbacklink(bl)
                ctx_btxsetbacktrace(concat(li," ",5))
                local uc = citetolist[tonumber(bl)]
                if uc then
                    ctx_btxsetinternal(uc.references.internal or "")
                end
            else
                -- nothing
            end
            local userdata = li[4]
            if userdata then
                local b = userdata.btxbtx
                local a = userdata.btxatx
                if b then
                    ctx_btxsetbefore(b)
                end
                if a then
                    ctx_btxsetafter(a)
                end
            end
            rendering.userdata = userdata
            if textmode then
                ctx_btxhandlelisttextentry()
            else
                ctx_btxhandlelistentry()
            end
            ctx_btxstoplistentry()
            --
         -- context(function()
         --     -- wrapup
         --     rendering.ignoredfields = nil
         -- end)
        end
    end

    local function getuserdata(dataset,key)
        local rendering = renderings[dataset]
        if rendering then
            local userdata = rendering.userdata
            if userdata then
                local value = userdata[key]
                if value and value ~= "" then
                    return value
                end
            end
        end
    end

    lists.uservariable = getuserdata

    function lists.filterall(dataset)
        local r = renderings[dataset]
        local list = r.list
        local registered = r.registered
        for i=1,#registered do
            list[i] = { registered[i], i, 0, false, false }
        end
    end

    implement {
        name      = "btxuservariable",
        actions   = { getuserdata, context },
        arguments = { "string", "string" }
    }

    implement {
        name      = "btxdoifelseuservariable",
        actions   = { getuserdata, ctx_doifelse },
        arguments = { "string", "string" }
    }

 -- implement {
 --     name      = "btxresolvelistreference",
 --     actions   = lists.resolve,
 --     arguments = { "string", "string" }
 -- }

    implement {
        name      = "btxcollectlistentries",
        actions   = lists.collectentries,
        arguments = {
            {
                { "names" },
                { "criterium" },
                { "reference" },
                { "method" },
                { "dataset" },
                { "keyword" },
                { "sorttype" },
                { "repeated" },
                { "ignored" },
                { "group" },
            },
        }
    }

    implement {
        name      = "btxpreparelistentries",
        actions   = lists.prepareentries,
        arguments = { "string" },
    }

    implement {
        name      = "btxfetchlistentries",
        actions   = lists.fetchentries,
        arguments = { "string" },
    }

    implement {
        name      = "btxflushlistentry",
        actions   = lists.flushentry,
        arguments = { "string", "integer" }
    }

    implement {
        name      = "btxdoifelsesameasprevious",
        actions   = { lists.sameasprevious, ctx_doifelse },
        arguments = { "string", "integer", "string" }
    }

end

do

    local citevariants        = { }
    publications.citevariants = citevariants

    local function btxhandlecite(specification)
        local dataset   = specification.dataset or v_default
        local reference = specification.reference
        local variant   = specification.variant
        if not variant or variant == "" then
            variant = "default"
        end
        if not reference or reference == "" then
            return
        end
        --
        specification.variant   = variant
        specification.compress  = specification.compress == v_yes
        specification.markentry = specification.markentry ~= false
        --
        local prefix, rest = lpegmatch(prefixsplitter,reference)
        if prefix and rest then
            dataset = prefix
            specification.dataset   = prefix
            specification.reference = rest
        end
        --
        if trace_cite then
            report_cite("inject, dataset: %s, tag: %s, variant: %s, compressed",
                specification.dataset or "-",
                specification.reference,
                specification.variant
            )
        end
        --
        ctx_btxsetdataset(dataset)
        --
        citevariants[variant](specification) -- we always fall back on default
    end

    local function btxhandlenocite(specification)
        local dataset   = specification.dataset or v_default
        local reference = specification.reference
        if not reference or reference == "" then
            return
        end
        --
        local markentry = specification.markentry ~= false
        local internal  = specification.internal or ""
        --
        local prefix, rest = lpegmatch(prefixsplitter,reference)
        if rest then
            dataset   = prefix
            reference = rest
        end
        --
        if trace_cite then
            report_cite("mark, dataset: %s, tags: %s",dataset or "-",reference)
        end
        --
        local reference = publications.parenttag(dataset,reference)
        --
        local found, todo, list = findallused(dataset,reference,internal)
        --
        tobemarked = markentry and todo
        if found and tobemarked then
            flushmarked(dataset,list)
            btxflushmarked() -- here (could also be done in caller)
        end
    end

    implement {
        name      = "btxhandlecite",
        actions   = btxhandlecite,
        arguments = {
            {
                { "dataset" },
                { "reference" },
                { "markentry", "boolean" },
                { "variant" },
                { "sorttype" },
                { "compress" },
                { "author" },
                { "lefttext" },
                { "righttext" },
                { "before" },
                { "after" },
            }
        }
    }

    implement {
        name      = "btxhandlenocite",
        actions   = btxhandlenocite,
        arguments = {
            {
               { "dataset" },
               { "reference" },
               { "markentry", "boolean" },
            }
        }
    }

    -- sorter

    local keysorter = function(a,b)
        local ak = a.sortkey
        local bk = b.sortkey
        if ak == bk then
            local as = a.suffix -- alphabetic
            local bs = b.suffix -- alphabetic
            if as and bs then
                return (as or "") < (bs or "")
            else
                return false
            end
        else
            return ak < bk
        end
    end

    local function compresslist(source)
        for i=1,#source do
            local t = type(source[i].sortkey)
            if t == "number" then
                -- okay
         -- elseif t == "string" then
         --     -- okay
            else
                return source
            end
        end
        local first, last, firstr, lastr
        local target, noftarget, tags = { }, 0, { }
        sort(source,keysorter)
        local oldvalue = nil
        local function flushrange()
            noftarget = noftarget + 1
            if last > first + 1 then
                target[noftarget] = {
                    first = firstr,
                    last  = lastr,
                    tags  = tags,
                }
            else
                target[noftarget] = firstr
                if last > first then
                    noftarget = noftarget + 1
                    target[noftarget] = lastr
                end
            end
            tags = { }
        end
        for i=1,#source do
            local entry = source[i]
            local current = entry.sortkey
            local suffix  = entry.suffix -- todo but what
            if not first then
                first, last, firstr, lastr = current, current, entry, entry
            elseif current == last + 1 then
                last, lastr = current, entry
            else
                flushrange()
                first, last, firstr, lastr = current, current, entry, entry
            end
            tags[#tags+1] = entry.tag
        end
        if first and last then
            flushrange()
        end
        return target
    end

    -- local source = {
    --     { tag = "one",   internal = 1, value = "foo", page = 1 },
    --     { tag = "two",   internal = 2, value = "bar", page = 2 },
    --     { tag = "three", internal = 3, value = "gnu", page = 3 },
    -- }
    --
    -- local target = compresslist(source)

    local numberonly = R("09")^1 / tonumber + P(1)^0
    local f_missing  = formatters["<%s>"]

    -- maybe also sparse (e.g. pages)

    -- a bit redundant access to datasets

    local function processcite(presets,specification)
        --
        if specification then
            setmetatableindex(specification,presets)
        else
            specification = presets
        end
        --
        local dataset    = specification.dataset
        local reference  = specification.reference
        local internal   = specification.internal
        local setup      = specification.variant
        local compress   = specification.compress
        local getter     = specification.getter
        local setter     = specification.setter
        local compressor = specification.compressor
        --
        local reference  = publications.parenttag(dataset,reference)
        --
        local found, todo, list = findallused(dataset,reference,internal)
        tobemarked = specification.markentry and todo
        --
        if not found or #found == 0 then
            report("nothing found for %a",reference)
        elseif not setup then
            report("invalid reference for %a",reference)
        else
            if trace_cite then
                report("processing reference %a",reference)
            end
            local source  = { }
            local badkey  = false
            local luadata = datasets[dataset].luadata
            for i=1,#found do
                local entry = found[i]
                local tag   = entry.userdata.btxref
                local ldata = luadata[tag]
                local data  = {
                    internal  = entry.references.internal,
                    language  = ldata.language,
                    dataset   = dataset,
                    tag       = tag,
                 -- luadata   = ldata,
                }
                setter(data,dataset,tag,entry)
                if compress and not compressor then
                    local sortkey = data.sortkey
                    if sortkey then
                        local key = lpegmatch(numberonly,sortkey)
                        if key then
                            data.sortkey = key
                        else
                            badkey = true
                        end
                    else
                        badkey = true
                    end
                end
                if type(data) == "table" then
                    source[#source+1] = data
                else
                    report("error in cite rendering %a",setup or "?")
                end
            end

            local lefttext  = specification.lefttext
            local righttext = specification.righttext
            local before    = specification.before
            local after     = specification.after

            if lefttext  and lefttext  ~= "" then lefttext  = settings_to_array(lefttext)  end
            if righttext and righttext ~= "" then righttext = settings_to_array(righttext) end
            if before    and before    ~= "" then before    = settings_to_array(before)    end
            if after     and after     ~= "" then after     = settings_to_array(after)     end

            local oneleft  = lefttext  and #lefttext  == 1 and lefttext [1]
            local oneright = righttext and #righttext == 1 and righttext[1]

            local function flush(i,n,entry,last)
                local tag = entry.tag
                local currentcitation = markcite(dataset,tag)
                --
                ctx_btxstartcite()
                ctx_btxsettag(tag)
                ctx_btxsetcategory(entry.category or "unknown")
                --
                if oneleft then
                    if i == 1 then
                        ctx_btxsetlefttext(oneleft)
                    end
                elseif lefttext then
                    ctx_btxsetlefttext(lefttext[i] or "")
                end
                if oneright then
                    if i == n then
                        ctx_btxsetrighttext(oneright)
                    end
                elseif righttext then
                    ctx_btxsetrighttext(righttext[i] or "")
                end
                if before then
                    ctx_btxsetbefore(before[i] or (#before == 1 and before[1]) or "")
                end
                if after then
                    ctx_btxsetafter(after[i] or (#after == 1 and after[1]) or "")
                end
                --
                ctx_btxsetbacklink(currentcitation)
                local bl = listtocite[currentcitation]
                if bl then
                    -- we refer to a coming list entry
                    ctx_btxsetinternal(bl.references.internal or "")
                else
                    -- we refer to a previous list entry
                    ctx_btxsetinternal(entry.internal or "")
                end
                local language = entry.language
                if language then
                    ctx_btxsetlanguage(language)
                end
                if not getter(entry,last) then
                    ctx_btxsetfirst("") -- (f_missing(tag))
                end
                ctx_btxsetconcat(concatstate(i,n))
                if trace_detail then
                    report("expanding cite setup %a",setup)
                end
                ctx_btxcitesetup(setup)
                ctx_btxstopcite()
            end

            if compress and not badkey then
                local target = (compressor or compresslist)(source)
                local nofcollected = #target
                if nofcollected == 0 then
                    report("nothing found for %a",reference)
                    unknowncite(reference)
                else
                    for i=1,nofcollected do
                        local entry = target[i]
                        local first = entry.first
                        if first then
                            flush(i,nofcollected,first,entry.last)
                        else
                            flush(i,nofcollected,entry)
                        end
                    end
                end
            else
                local nofcollected = #source
                if nofcollected == 0 then
                    unknowncite(reference)
                else
                    for i=1,nofcollected do
                        flush(i,nofcollected,source[i])
                    end
                end
            end
        end
        if tobemarked then
            flushmarked(dataset,list)
            btxflushmarked() -- here (could also be done in caller)
        end
    end

    --

    local function simplegetter(first,last,field)
        local value = first[field]
        if value then
            ctx_btxsetfirst(value)
            if last then
                ctx_btxsetsecond(last[field])
            end
            return true
        end
    end

    local setters = setmetatableindex({},function(t,k)
        local v = function(data,dataset,tag,entry)
            local value = getcasted(dataset,tag,k)
            data.value   = value -- not really needed
            data[k]      = value
            data.sortkey = value
            data.sortfld = k
        end
        t[k] = v
        return v
    end)

    local getters = setmetatableindex({},function(t,k)
        local v = function(first,last)
            return simplegetter(first,last,k)
        end
        t[k] = v
        return v
    end)

    setmetatableindex(citevariants,function(t,k)
        local p = defaultvariant or "default"
        local v = rawget(t,p)
        report_cite("variant %a falls back on %a setter and getter with setup %a",k,p,k)
        t[k] = v
        return v
    end)

    function citevariants.default(presets)
        local variant = presets.variant
        processcite(presets,{
            setup   = variant,
            setter  = setters[variant],
            getter  = getters[variant],
        })
    end

    -- category | type

    do

        local function setter(data,dataset,tag,entry)
            data.category = getfield(dataset,tag,"category")
        end

        local function getter(first,last)
            return simplegetter(first,last,"category")
        end

        function citevariants.category(presets)
            processcite(presets,{
             -- variant  = presets.variant or "serial",
                setter  = setter,
                getter  = getter,
            })
        end

        function citevariants.type(presets)
            processcite(presets,{
             -- variant  = presets.variant or "type",
                setter  = setter,
                getter  = getter,
            })
        end

    end


    -- entry (we could provide a generic one)

    do

        local function setter(data,dataset,tag,entry)
            -- nothing
        end

        local function getter(first,last) -- last not used
            ctx_btxsetfirst(first.tag)
        end

        function citevariants.entry(presets)
            processcite(presets,{
                compress = false,
             -- variant  = presets.variant or "entry",
                setter   = setter,
                getter   = getter,
            })
        end

    end

    -- short

    do

        local function setter(data,dataset,tag,entry)
            data.short  = getdetail(dataset,tag,"short")
            data.suffix = getdetail(dataset,tag,"suffix")
        end

        local function getter(first,last) -- last not used
            local short = first.short
            if short then
                local suffix = first.suffix
                if suffix then
                    ctx_btxsetfirst(short .. suffix)
                else
                    ctx_btxsetfirst(short)
                end
                return true
            end
        end

        function citevariants.short(presets)
            processcite(presets,{
                compress = false,
             -- variant  = presets.variant or "short",
                setter   = setter,
                getter   = getter,
            })
        end

    end

    -- pages (no compress)

    do

        local function setter(data,dataset,tag,entry)
            data.pages = getcasted(dataset,tag,"pages")
        end

        local function getter(first,last)
            local pages = first.pages
            if pages then
                if type(pages) == "table" then
                    ctx_btxsetfirst(pages[1])
                    ctx_btxsetsecond(pages[2])
                else
                    ctx_btxsetfirst(pages)
                end
                return true
            end
        end

        function citevariants.page(presets)
            processcite(presets,{
             -- variant = presets.variant or "page",
                setter  = setter,
                getter  = getter,
            })
        end

    end

    -- num

    do

        local function setter(data,dataset,tag,entry)
            local entries = entry.entries
            local text    = entries and entries.text or "?"
            data.num      = text
            data.sortkey  = text
        end

        local function getter(first,last)
            return simplegetter(first,last,"num")
        end

        function citevariants.num(presets)
            processcite(presets,{
             -- variant = presets.variant or "num",
                setter  = setter,
                getter  = getter,
            })
        end

    end

    -- year

    do

        local function setter(data,dataset,tag,entry)
            local year   = getfield (dataset,tag,"year")
            local suffix = getdetail(dataset,tag,"suffix")
            data.year    = year
            data.suffix  = suffix
            data.sortkey = tonumber(year) or 0
        end

        local function getter(first,last)
            return simplegetter(first,last,"year")
        end

        function citevariants.year(presets)
            processcite(presets,{
             -- variant  = presets.variant or "year",
                setter  = setter,
                getter  = getter,
            })
        end

    end

    -- index | serial

    do

        local function setter(data,dataset,tag,entry)
            local index = getfield(dataset,tag,"index")
            data.index   = index
            data.sortkey = index
        end

        local function getter(first,last)
            return simplegetter(first,last,"index")
        end

        function citevariants.index(presets)
            processcite(presets,{
             -- variant  = presets.variant or "index",
                setter  = setter,
                getter  = getter,
            })
        end

        function citevariants.serial(presets)
            processcite(presets,{
             -- variant  = presets.variant or "serial",
                setter  = setter,
                getter  = getter,
            })
        end

    end

    -- key | tag

    do

        local function setter(data,dataset,tag,entry)
            -- nothing
        end

        local function getter(first,last)
            ctx_btxsetfirst(first.tag)
            return true
        end

        function citevariants.key(presets)
            return processcite(presets,{
                variant = "key",
                setter  = setter,
                getter  = getter,
            })
        end

        function citevariants.tag(presets)
            return processcite(presets,{
                variant = "tag",
                setter  = setter,
                getter  = getter,
            })
        end

    end

    -- keyword

    do

        local function listof(list)
            local size = type(list) == "table" and #list or 0
            if size > 0 then
                return function()
                    for i=1,size do
                        ctx_btxsetfirst(list[i])
                        ctx_btxsetconcat(concatstate(i,size))
                        ctx_btxcitesetup("listelement")
                    end
                    return true
                end
            else
                return "?" -- unknown
            end
        end

        local function setter(data,dataset,tag,entry)
            data.keywords = getcasted(dataset,tag,"keywords")
        end

        local function getter(first,last)
            context(listof(first.keywords))
        end

        function citevariants.keywords(presets)
            return processcite(presets,{
                variant = "keywords",
                setter  = setter,
                getter  = getter,
            })
        end

    end

    -- authors

    do

        local currentbtxciteauthor = function()
            context.currentbtxciteauthor()
            return true -- needed?
        end

        local function authorcompressor(found)
            local result  = { }
            local entries = { }
            for i=1,#found do
                local entry  = found[i]
                local author = entry.author
                if author then
                    local aentries = entries[author]
                    if aentries then
                        aentries[#aentries+1] = entry
                    else
                        entries[author] = { entry }
                    end
                end
            end
            -- beware: we usetables as hash so we get a cycle when inspecting (unless we start
            -- hashing with strings)
            for i=1,#found do
                local entry  = found[i]
                local author = entry.author
                if author then
                    local aentries = entries[author]
                    if not aentries then
                        result[#result+1] = entry
                    elseif aentries == true then
                        -- already done
                    else
                        result[#result+1] = entry
                        entry.entries = aentries
                        entries[author] = true
                    end
                end
            end
            -- todo: add letters (should we then tag all?)
            return result
        end

        local function authorconcat(target,key,setup)
            ctx_btxstartsubcite(setup)
            local nofcollected = #target
            if nofcollected == 0 then
                unknowncite(tag)
            else
                for i=1,nofcollected do
                    local entry = target[i]
                    local first = entry.first
                    local tag   = entry.tag
                    local currentcitation = markcite(entry.dataset,tag)
                    ctx_btxstartciteauthor()
                    ctx_btxsettag(tag)
                    ctx_btxsetbacklink(currentcitation)
                    local bl = listtocite[currentcitation]
                    ctx_btxsetinternal(bl and bl.references.internal or "")
                    if first then
                        ctx_btxsetfirst(first[key] or "") -- f_missing(first.tag))
                        local suffix = entry.suffix
                        local value  = entry.last[key]
                        if value then
                            ctx_btxsetsecond(value)
                        end
                        if suffix then
                            ctx_btxsetthird(suffix)
                        end
                    else
                        local suffix = entry.suffix
                        local value  = entry[key] or "" -- f_missing(tag)
                        ctx_btxsetfirst(value)
                        if suffix then
                            ctx_btxsetthird(suffix)
                        end
                    end
                    ctx_btxsetconcat(concatstate(i,nofcollected))
                    if trace_detail then
                        report("expanding %a cite setup %a","multiple author",setup)
                    end
                    ctx_btxcitesetup(setup)
                    ctx_btxstopciteauthor()
                end
            end
            ctx_btxstopsubcite()
        end

        local function authorsingle(entry,key,setup)
            ctx_btxstartsubcite(setup)
            ctx_btxstartciteauthor()
            local tag = entry.tag
            ctx_btxsettag(tag)
         -- local currentcitation = markcite(entry.dataset,tag)
         -- ctx_btxsetbacklink(currentcitation)
         -- local bl = listtocite[currentcitation]
         -- ctx_btxsetinternal(bl and bl.references.internal or "")
            ctx_btxsetfirst(entry[key] or "") -- f_missing(tag)
            if suffix then
                ctx_btxsetthird(entry.suffix)
            end
            if trace_detail then
                report("expanding %a cite setup %a","single author",setup)
            end
            ctx_btxcitesetup(setup)
            ctx_btxstopciteauthor()
            ctx_btxstopsubcite()
        end

        local partialinteractive = false

        local function authorgetter(first,last,key,setup) -- only first
         -- ctx_btxsetfirst(first.author)         -- unformatted
         -- ctx_btxsetfirst(currentbtxciteauthor) -- formatter (much slower)
            if first.type == "author" then
                ctx_btxsetfirst(currentbtxciteauthor) -- formatter (much slower)
            else
                ctx_btxsetfirst(first.author)         -- unformatted
            end
            local entries = first.entries
            -- alternatively we can use a concat with one ... so that we can only make the
            -- year interactive, as with the concat
            if partialinteractive and not entries then
                entries = { first }
            end
            if entries then
                -- happens with year
                local c = compresslist(entries)
                local f = function() authorconcat(c,key,setup) return true end -- indeed return true?
                ctx_btxsetcount(#c)
                ctx_btxsetsecond(f)
            elseif first then
                -- happens with num
                local f = function() authorsingle(first,key,setup) return true end -- indeed return true?
                ctx_btxsetcount(0)
                ctx_btxsetsecond(f)
            end
            return true
        end

        -- author

        local function setter(data,dataset,tag,entry)
            data.author, data.field, data.type = getcasted(dataset,tag,"author")
        end

        local function getter(first,last,_,setup)
            if first.type == "author" then
                ctx_btxsetfirst(currentbtxciteauthor) -- formatter (much slower)
            else
                ctx_btxsetfirst(first.author)         -- unformatted
            end
            return true
        end

        function citevariants.author(presets)
            processcite(presets,{
                compress = false,
                variant  = "author",
                setter   = setter,
                getter   = getter,
            })
        end

        -- authornum

        local function setter(data,dataset,tag,entry)
            local entries = entry.entries
            local text    = entries and entries.text or "?"
            data.author, data.field, data.type = getcasted(dataset,tag,"author")
            data.num     = text
            data.sortkey = text and lpegmatch(numberonly,text)
        end

        local function getter(first,last)
            authorgetter(first,last,"num","author:num")
            return true
        end

        function citevariants.authornum(presets)
            processcite(presets,{
                variant    = "authornum",
                setter     = setter,
                getter     = getter,
                compressor = authorcompressor,
            })
        end

        -- authoryear | authoryears

        local function setter(data,dataset,tag,entry)
            data.author, data.field, data.type = getcasted(dataset,tag,"author")
            local year   = getfield (dataset,tag,"year")
            local suffix = getdetail(dataset,tag,"suffix")
            data.year    = year
            data.suffix  = suffix
            data.sortkey = tonumber(year) or 0
        end

        local function getter(first,last)
            authorgetter(first,last,"year","author:year")
            return true
        end

        function citevariants.authoryear(presets)
            processcite(presets,{
                variant    = "authoryear",
                setter     = setter,
                getter     = getter,
                compressor = authorcompressor,
            })
        end

        local function getter(first,last)
            authorgetter(first,last,"year","author:years")
            return true
        end

        function citevariants.authoryears(presets)
            processcite(presets,{
                variant    = "authoryears",
                setter     = setter,
                getter     = getter,
                compressor = authorcompressor,
            })
        end

    end

end

-- List variants

do

    local listvariants        = { }
    publications.listvariants = listvariants

    local function btxlistvariant(dataset,block,tag,variant,listindex)
        local action = listvariants[variant] or listvariants.default
        if action then
            action(dataset,block,tag,variant,tonumber(listindex) or 0)
        end
    end

    implement {
        name      = "btxlistvariant",
        actions   = btxlistvariant,
        arguments = { "string", "string", "string", "string", "string" } -- not integer here
    }

    function listvariants.default(dataset,block,tag,variant)
        ctx_btxsetfirst("?")
        if trace_detail then
            report("expanding %a list setup %a","default",variant)
        end
        ctx_btxlistsetup(variant)
    end

    function listvariants.num(dataset,block,tag,variant,listindex)
        ctx_btxsetfirst(listindex)
        if trace_detail then
            report("expanding %a list setup %a","num",variant)
        end
        ctx_btxlistsetup(variant)
    end

    listvariants[v_yes] = listvariants.num
    listvariants.bib    = listvariants.num

    function listvariants.short(dataset,block,tag,variant,listindex)
        local short  = getdetail(dataset,tag,"short","short")
        local suffix = getdetail(dataset,tag,"suffix","suffix")
        if short then
            ctx_btxsetfirst(short)
        end
        if suffix then
            ctx_btxsetthird(suffix)
        end
        if trace_detail then
            report("expanding %a list setup %a","short",variant)
        end
        ctx_btxlistsetup(variant)
    end

    function listvariants.page(dataset,block,tag,variant,listindex)
        local rendering     = renderings[dataset]
        local specification = rendering.list[listindex]
        for i=3,#specification do
            local backlink = tonumber(specification[i])
            if backlink then
                local citation = citetolist[backlink]
                if citation then
                    local references = citation.references
                    if references then
                        local internal = references.internal
                        local realpage = references.realpage
                        if internal and realpage then
                            ctx_btxsetconcat(i-2)
                            ctx_btxsetfirst(realpage)
                            ctx_btxsetsecond(backlink)
                            if trace_detail then
                                report("expanding %a list setup %a","page",variant)
                            end
                            ctx_btxlistsetup(variant)
                        end
                    end
                end
            end
        end
    end

end
