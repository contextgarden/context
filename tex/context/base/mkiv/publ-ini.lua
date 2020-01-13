if not modules then modules = { } end modules ['publ-ini'] = {
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
local match, find, gsub = string.match, string.find, string.gsub
local concat, sort, tohash = table.concat, table.sort, table.tohash
local mod = math.mod
local formatters = string.formatters
local allocate = utilities.storage.allocate
local settings_to_array, settings_to_set = utilities.parsers.settings_to_array, utilities.parsers.settings_to_set
local sortedkeys, sortedhash = table.sortedkeys, table.sortedhash
local setmetatableindex = table.setmetatableindex
local lpegmatch = lpeg.match
local P, S, C, Ct, Cs, R, Carg = lpeg.P, lpeg.S, lpeg.C, lpeg.Ct, lpeg.Cs, lpeg.R, lpeg.Carg
local upper = characters.upper

local report             = logs.reporter("publications")
local report_cite        = logs.reporter("publications","cite")
local report_list        = logs.reporter("publications","list")
local report_suffix      = logs.reporter("publications","suffix")

local trace              = false  trackers.register("publications",                 function(v) trace            = v end)
local trace_cite         = false  trackers.register("publications.cite",            function(v) trace_cite       = v end)
local trace_missing      = false  trackers.register("publications.cite.missing",    function(v) trace_missing    = v end)
local trace_references   = false  trackers.register("publications.cite.references", function(v) trace_references = v end)
local trace_details      = false  trackers.register("publications.details",         function(v) trace_details    = v end)
local trace_suffixes     = false  trackers.register("publications.suffixes",        function(v) trace_suffixes   = v end)

publications             = publications or { }
local datasets           = publications.datasets
local writers            = publications.writers
local casters            = publications.casters
local detailed           = publications.detailed
local enhancer           = publications.enhancer
local enhancers          = publications.enhancers

local tracers            = publications.tracers or { }
publications.tracers     = tracers

local setmacro           = interfaces.setmacro   -- todo
local setcounter         = tex.setcounter        -- todo
local variables          = interfaces.variables

local v_local            = variables["local"]
local v_global           = variables["global"]

local v_force            = variables.force
local v_normal           = variables.normal
local v_reverse          = variables.reverse
local v_none             = variables.none
local v_yes              = variables.yes
local v_no               = variables.no
local v_all              = variables.all
local v_always           = variables.always
local v_text             = variables.text
local v_doublesided      = variables.doublesided
local v_default          = variables.default
local v_dataset          = variables.dataset

local conditionals       = tex.conditionals

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

local ctx_doifelse                = commands.doifelse
local ctx_doif                    = commands.doif
local ctx_doifnot                 = commands.doifnot
local ctx_gobbletwoarguments      = context.gobbletwoarguments

local ctx_btxhandlelistentry      = context.btxhandlelistentry
local ctx_btxhandlecombientry     = context.btxhandlecombientry
local ctx_btxchecklistentry       = context.btxchecklistentry

local ctx_btxsetdataset           = context.btxsetdataset
local ctx_btxsettag               = context.btxsettag
local ctx_btxsetnumber            = context.btxsetnumber
local ctx_btxsetlanguage          = context.btxsetlanguage
local ctx_btxsetcombis            = context.btxsetcombis
local ctx_btxsetcategory          = context.btxsetcategory
local ctx_btxsetfirst             = context.btxsetfirst
local ctx_btxsetsecond            = context.btxsetsecond
local ctx_btxsetsuffix            = context.btxsetsuffix
local ctx_btxsetinternal          = context.btxsetinternal
local ctx_btxsetlefttext          = context.btxsetlefttext
local ctx_btxsetrighttext         = context.btxsetrighttext
local ctx_btxsetbefore            = context.btxsetbefore
local ctx_btxsetafter             = context.btxsetafter
local ctx_btxsetbacklink          = context.btxsetbacklink
local ctx_btxsetfirstinternal     = context.btxsetfirstinternal
local ctx_btxsetlastinternal      = context.btxsetlastinternal
local ctx_btxsetauthorfield       = context.btxsetauthorfield

-- local ctx_btxsetdataset           = function(s) setmacro("currentbtxdataset",       s) end -- context.btxsetdataset
-- local ctx_btxsettag               = function(s) setmacro("currentbtxtag",           s) end -- context.btxsettag
-- local ctx_btxsetnumber            = function(s) setmacro("currentbtxnumber",        s) end -- context.btxsetnumber
-- local ctx_btxsetlanguage          = function(s) setmacro("currentbtxlanguage",      s) end -- context.btxsetlanguage
-- local ctx_btxsetcombis            = function(s) setmacro("currentbtxcombis",        s) end -- context.btxsetcombis
-- local ctx_btxsetcategory          = function(s) setmacro("currentbtxcategory",      s) end -- context.btxsetcategory
-- local ctx_btxsetfirst             = function(s) setmacro("currentbtxfirst",         s) end -- context.btxsetfirst
-- local ctx_btxsetsecond            = function(s) setmacro("currentbtxsecond",        s) end -- context.btxsetsecond
-- local ctx_btxsetsuffix            = function(s) setmacro("currentbtxsuffix",        s) end -- context.btxsetsuffix
-- local ctx_btxsetinternal          = function(s) setmacro("currentbtxinternal",      s) end -- context.btxsetinternal
-- local ctx_btxsetlefttext          = function(s) setmacro("currentbtxlefttext",      s) end -- context.btxsetlefttext
-- local ctx_btxsetrighttext         = function(s) setmacro("currentbtxrighttext",     s) end -- context.btxsetrighttext
-- local ctx_btxsetbefore            = function(s) setmacro("currentbtxbefore",        s) end -- context.btxsetbefore
-- local ctx_btxsetafter             = function(s) setmacro("currentbtxafter",         s) end -- context.btxsetafter
-- local ctx_btxsetbacklink          = function(s) setmacro("currentbtxbacklink",      s) end -- context.btxsetbacklink
-- local ctx_btxsetfirstinternal     = function(s) setmacro("currentbtxfirstinternal", s) end -- context.btxsetfirstinternal
-- local ctx_btxsetlastinternal      = function(s) setmacro("currentbtxlastinternal",  s) end -- context.btxsetlastinternal

local ctx_btxsetfirstpage         = context.btxsetfirstpage
local ctx_btxsetlastpage          = context.btxsetlastpage

local ctx_btxstartcite            = context.btxstartcite
local ctx_btxstopcite             = context.btxstopcite
local ctx_btxstartciteauthor      = context.btxstartciteauthor
local ctx_btxstopciteauthor       = context.btxstopciteauthor
local ctx_btxstartsubcite         = context.btxstartsubcite
local ctx_btxstopsubcite          = context.btxstopsubcite
local ctx_btxstartlistentry       = context.btxstartlistentry
local ctx_btxstoplistentry        = context.btxstoplistentry
local ctx_btxstartcombientry      = context.btxstartcombientry
local ctx_btxstopcombientry       = context.btxstopcombientry

local ctx_btxflushauthor          = context.btxflushauthor

local ctx_btxsetnoflistentries    = context.btxsetnoflistentries
local ctx_btxsetcurrentlistentry  = context.btxsetcurrentlistentry
local ctx_btxsetcurrentlistindex  = context.btxsetcurrentlistindex

local ctx_btxsetcount             = context.btxsetcount
local ctx_btxsetconcat            = context.btxsetconcat

local ctx_btxcitesetup            = context.btxcitesetup
local ctx_btxsubcitesetup         = context.btxsubcitesetup
local ctx_btxnumberingsetup       = context.btxnumberingsetup
local ctx_btxpagesetup            = context.btxpagesetup
local ctx_btxlistsetup            = context.btxlistsetup

local trialtypesetting            = context.trialtypesetting

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

logs.registerfinalactions(function()
    local done    = false
    local unknown = false
    for name, dataset in sortedhash(datasets) do
        for command, n in sortedhash(dataset.commands) do
            if not done then
                logs.startfilelogging(report,"used btx commands")
                done = true
            end
            if isdefined(command) then
                report("%-20s %-20s % 5i %s",name,command,n,"known")
            elseif isdefined(upper(command)) then
                report("%-20s %-20s % 5i %s",name,command,n,"KNOWN")
            else
                report("%-20s %-20s % 5i %s",name,command,n,"unknown")
                unknown = true
            end
        end
    end
    if done then
        logs.stopfilelogging()
    end
    if unknown and logs.loggingerrors() then
        logs.starterrorlogging(report,"unknown btx commands")
        for name, dataset in sortedhash(datasets) do
            for command, n in sortedhash(dataset.commands) do
                if not isdefined(command) and not isdefined(upper(command)) then
                    report("%-20s %-20s % 5i %s",name,command,n,"unknown")
                end
            end
        end
        logs.stoperrorlogging()
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
        for name, state in sortedhash(collected) do
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
local listtolist   = nil

do

    local initialize = nil -- we delay

    initialize = function(t)
        usedentries     = allocate { }
        citetolist      = allocate { }
        listtocite      = allocate { }
        listtolist      = allocate { }
        local names     = { }
        local p_collect = (C(R("09")^1) * Carg(1) / function(s,entry) listtocite[tonumber(s)] = entry end + P(1))^0
        local nofunique = 0
        local nofreused = 0
     -- local internals = references.sortedinternals -- todo: when we need it more than once
     -- for i=1,#internals do                        -- but currently we don't do this when not
     --     local entry = internals[i]               -- needed anyway so ...
        local internals = structures.references.internals
        for i, entry in sortedhash(internals) do
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
                            local int = tonumber(userdata.btxint)
                            if int then
                                listtocite[int] = entry
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
                elseif kind == "btx" then
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
        end
        for k, v in sortedhash(names) do
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
        if trace_details then
            report("%s unique references, %s reused entries",nofunique,nofreused)
        end
        initialize = nil
    end

    usedentries = setmetatableindex(function(_,k) if initialize then initialize() end return usedentries[k] end)
    citetolist  = setmetatableindex(function(_,k) if initialize then initialize() end return citetolist [k] end)
    listtocite  = setmetatableindex(function(_,k) if initialize then initialize() end return listtocite [k] end)
    listtolist  = setmetatableindex(function(_,k) if initialize then initialize() end return listtolist [k] end)

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
    ----- finder   = publications.finder

    findallused = function(dataset,reference,internal,forcethem)
        local current  = datasets[dataset]
        local finder   = publications.finder -- for the moment, not yet in all betas
        local find     = finder and finder(current,reference)
        local tags     = not find and settings_to_array(reference)
        local todo     = { }
        local okay     = { } -- only if mark
        local allused  = usedentries[dataset] or { }
     -- local allused  = usedentries[dataset] -- only test
        local luadata  = current.luadata
        local details  = current.details
        local ordered  = current.ordered
        if allused then -- always true
            local registered = { }
            local function register(tag)
                local entry = forcethem and luadata[tag]
                if entry then
                    if registered[tag] then
                        if trace_cite then
                            report_cite("dataset: %s, tag: %s, state: %s",dataset,tag,"already cited (1)")
                        end
                        return
                    elseif trace_cite then
                        report_cite("dataset: %s, tag: %s, state: %s",dataset,tag,"okay")
                    end
                    okay[#okay+1] = entry
                 -- todo[tag] = true
                    registered[tag] = true
                    return tag
                end
                entry = allused[tag]
                if trace_cite then
                    report_cite("dataset: %s, tag: %s, used: % t",dataset,tag,table.sortedkeys(allused))
                end
                if not entry then
                    local parent = details[tag].parent
                    if parent then
                        entry = allused[parent]
                    end
                    if entry then
                        report("using reference of parent %a for %a",parent,tag)
                        tag = parent
                    elseif trace_cite then
                        report_cite("dataset: %s, tag: %s, state: %s",dataset,tag,"not used")
                    end
                elseif trace_cite then
                    report_cite("dataset: %s, tag: %s, state: %s",dataset,tag,"used")
                end
                if registered[tag] then
                    if trace_cite then
                        report_cite("dataset: %s, tag: %s, state: %s",dataset,tag,"already cited (2)")
                    end
                    return
                end
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
                    if not entry then
                        report_cite("dataset: %s, tag: %s, state: %s",dataset,tag,"no entry (1)")
                    elseif trace_cite then
                        report_cite("dataset: %s, tag: %s, state: %s",dataset,tag,"new entry")
                    end
                    okay[#okay+1] = entry
                elseif not entry then
                    if trace_cite then
                        report_cite("dataset: %s, tag: %s, state: %s",dataset,tag,"no entry (2)")
                    end
        -- okay[#okay+1] = luadata[tag]
                end
                todo[tag] = true
                registered[tag] = true
                return tag
            end
            if reference == "*" then
                tags = { }
                for i=1,#ordered do
                    local tag = ordered[i].tag
                    tag = register(tag)
                    tags[#tags+1] = tag
                end
            elseif find then
                tags = { }
                for i=1,#ordered do
                    local entry = ordered[i]
                    if find(entry) then
                        local tag = entry.tag
                        tag = register(tag)
                        tags[#tags+1] = tag
                    end
                end
                if #tags == 0 and not reported[reference] then
                    tags[1] = reference
                    reported[reference] = true
                end
            else
                for i=1,#tags do
                    local tag = tags[i]
                    if luadata[tag] then
                        tag = register(tag)
                        tags[i] = tag
                    elseif not reported[tag] then
                        reported[tag] = true
                        report_cite("non-existent entry %a in %a",tag,dataset)
                    end
                end
            end
        elseif find then
            tags = { }
            for i=1,#ordered do
                local entry = ordered[i]
                if find(entry) then
                    local tag    = entry.tag
                    local parent = details[tag].parent
                    if parent then
                        tag = parent
                    end
                    tags[#tags+1] = tag
                    todo[tag] = true
                 -- okay[#okay+1] = entry -- only test
                end
            end
            if #tags == 0 and not reported[reference] then
                tags[1] = reference
                reported[reference] = true
            end
        else
            for i=1,#tags do
                local tag    = tags[i]
                local parent = details[tag].parent
                if parent then
                    tag = parent
                    tags[i] = tag
                end
                local entry = luadata[tag]
                if entry then
                    todo[tag] = true
                 -- okay[#okay+1] = entry -- only test
                elseif not reported[tag] then
                    reported[tag] = true
                    report_cite("non-existent entry %a in %a",tag,dataset)
                end
            end
        end
        return okay, todo, tags
    end

    local firstoftwoarguments  = context.firstoftwoarguments
    local secondoftwoarguments = context.secondoftwoarguments

    implement {
        name      = "btxdoifelsematches",
        arguments = "3 strings",
        actions   = function(dataset,tag,expression)
            local find = publications.finder(dataset,expression)
            local okay = false
            if find then
                local d = datasets[dataset]
                if d then
                    local e = d.luadata[tag]
                    if e and find(e) then
                        firstoftwoarguments()
                        return
                    end
                end
            end
            secondoftwoarguments()
        end
    }

end

local function unknowncite(reference)
    ctx_btxsettag(reference)
    if trace_details then
        report("expanding %a cite setup %a","unknown","unknown")
    end
    ctx_btxcitesetup("unknown")
end

local concatstate = publications.concatstate

-- hidden : mark for list, don't show in text
-- list   : mark for list, show in text only when in list
-- text   : not to list, show in text
-- always : mark for list, show in text

local marked_todo    = false -- keeps track or not yet flushed
local marked_dataset = false
local marked_list    = false -- the sequential list (we flush in order, not by unordered hash)
local marked_method  = false

local function marknocite(dataset,tag,nofcitations,setup)
    ctx_btxstartcite()
    ctx_btxsetdataset(dataset)
    ctx_btxsettag(tag)
    ctx_btxsetbacklink(nofcitations)
    if trace_details then
        report("expanding cite setup %a",setup)
    end
    ctx_btxcitesetup(setup)
    ctx_btxstopcite()
end

local function markcite(dataset,tag,flush)
    if not marked_todo then
        return 0
    end
    local citation = marked_todo[tag]
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
        marked_todo[tag] = nofcitations -- signal that it's marked
        return nofcitations
    else
        return citation
    end
end

local function btxflushmarked()
    if marked_list and marked_todo then
        for i=1,#marked_list do
            -- keep order
            local tag = marked_list[i]
            local tbm = marked_todo[tag]
            if tbm == true or not tbm then
                nofcitations = nofcitations + 1
                local setup = (tbm or marked_method == v_always) and "nocite" or "invalid"
                marknocite(marked_dataset,tag,nofcitations,setup)
                if trace_cite then
                    report_cite("mark, dataset: %s, tag: %s, number: %s, setup: %s",marked_dataset,tag,nofcitations,setup)
                end
            else
                -- a number signaling being marked
            end
        end
    end
    marked_todo    = false
    marked_dataset = false
    marked_list    = false
    marked_method  = false
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

implement {
    name      = "btxsingularorplural",
    actions   = { publications.singularorplural, ctx_doifelse },
    arguments = "3 strings"
}

implement {
    name      = "btxoneorrange",
    actions   = { publications.oneorrange, function(b) if b == nil then ctx_gobbletwoarguments() else ctx_doifelse(b) end end },
    arguments = "3 strings"
}

implement {
    name      = "btxfirstofrange",
    actions   = { publications.firstofrange, context },
    arguments = "3 strings"
}

implement {
    name      = "btxlastofrange",
    actions   = { publications.lastofrange, context },
    arguments = "3 strings"
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

implement {
    name       = "convertbtxdatasettoxml",
    arguments  = { "string", true },
    actions    = publications.converttoxml
}

-- enhancing

do

    -- maybe not redo when already done

    local function shortsorter(a,b)
        local ay = a[2] -- year
        local by = b[2] -- year
        if ay ~= by then
            return ay < by
        end
        local ay = a[3] -- suffix
        local by = b[3] -- suffix
        if ay ~= by then
            -- bah, bah, bah
            local an = tonumber(ay)
            local bn = tonumber(by)
            if an and bn then
                return an < bn
            else
                return ay < by
            end
        end
        return a[4] < b[4]
    end

    -- We could avoid loops by combining enhancers but that makes it only
    -- more messy and for documents that use publications the few extra milli
    -- seconds are irrelevant (there is for sure more to gain by proper coding
    -- of the source and or style).

    local f_short = formatters["%s%02i"]

    function publications.enhancers.suffixes(dataset)
        if not dataset then
            return -- bad news
        else
            report("analyzing previous publication run for %a",dataset.name)
        end
        dataset.suffixed = true
        --
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
        -- we have two suffixes: author (dependent of type) and short
        local kind    = dataset.authorconversion or "name"
        local fields  = { "author", "editor" } -- will be entry in data definition
        local shorts  = { }
        local authors = { }
        local hasher  = publications.authorhashers[kind]
        local shorter = publications.authorhashers.short
        for i=1,#ordered do
            local entry = ordered[i]
            if entry then
                local tag = entry.tag
                if tag then
                    local use = used[tag]
                    if use then
                        -- use is a table of used list entries (so there can be more) and we just look at
                        -- the first one for btx properties
                        local listentry = use[1]
                        local userdata  = listentry.userdata
                        local btxspc    = userdata and userdata.btxspc
                        if btxspc then
                            -- we could act on the 3rd arg returned by getcasted but in general any string will do
                            -- so we deal with it in the author hashers ... maybe some day ...
                            local done = false
                            for i=1,#fields do
                                local field = fields[i]
                                local author = getcasted(dataset,tag,field,specifications[btxspc])
                                local kind   = type(author)
                                if kind == "table" or kind == "string" then
                                    if u then
                                        u = listentry.entries.text -- hm
                                    else
                                        u = "0"
                                    end
                                    local year  = tonumber(entry.year) or 9999
                                    local data  = { tag, year, u, i }
                                    -- authors
                                    local hash  = hasher(author)
                                    local found = authors[hash]
                                    if not found then
                                        authors[hash] = { data }
                                    else
                                        found[#found+1] = data
                                    end
                                    -- shorts
                                    local hash  = shorter(author)
                                    local short = f_short(hash,mod(year,100))
                                    local found = shorts[short]
                                    if not found then
                                        shorts[short] = { data }
                                    else
                                        found[#found+1] = data
                                    end
                                    done = true
                                    break
                                end
                            end
                            if not done then
                                report("unable to create short for %a, needs one of [%,t]",tag,fields)
                            end
                        else
                            --- no spec so let's forget about it
                        end
                    end
                end
            end
        end
        local function addsuffix(hashed,key,suffixkey)
            for hash, tags in sortedhash(hashed) do -- ordered ?
                local n = #tags
                if n == 0 then
                    -- skip
                elseif n == 1 then
                    local tagdata = tags[1]
                    local tag     = tagdata[1]
                    local detail  = details[tag]
                    local entry   = luadata[tag]
                    local year    = entry.year
                    detail[key]   = hash
                elseif n > 1 then
                    sort(tags,shortsorter) -- or take first -- todo: proper utf sorter
                    local lastyear = nil
                    local suffix   = nil
                    local previous = nil
                    for i=1,n do
                        local tagdata = tags[i]
                        local tag     = tagdata[1]
                        local detail  = details[tag]
                        local entry   = luadata[tag]
                        local year    = entry.year
                        detail[key]   = hash
                        if not year or year ~= lastyear then
                            lastyear = year
                            suffix = 1
                        else
                            if previous and suffix == 1 then
                                previous[suffixkey] = suffix
                            end
                            suffix = suffix + 1
                            detail[suffixkey] = suffix
                        end
                        previous = detail
                    end
                end
                if trace_suffixes then
                    for i=1,n do
                        local tag    = tags[i][1]
                        local year   = luadata[tag].year
                        local suffix = details[tag].suffix
                        if suffix then
                            report_suffix("%s: tag %a, hash %a, year %a, suffix %a",key,tag,hash,year or '',suffix or '')
                        else
                            report_suffix("%s: tag %a, hash %a, year %a",key,tag,hash,year or '')
                        end
                    end
                end
            end
        end
        addsuffix(shorts, "shorthash", "shortsuffix") -- todo: shorthash
        addsuffix(authors,"authorhash","authorsuffix")
    end

 -- utilities.sequencers.appendaction(enhancer,"system","publications.enhancers.suffixes")

end

implement {
    name      = "btxaddentry",
    arguments = "3 strings",
    actions   = function(name,settings,content)
        local dataset = datasets[name]
        if dataset then
            publications.addtexentry(dataset,settings,content)
        end
    end,
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
    arguments = "2 strings",
    actions   = { publications.checkeddataset, context },
}

implement {
    name      = "btxsetentry",
    arguments = "2 strings",
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
        local virtualfields = currentspecification.virtualfields
        if virtualfields and virtualfields[field] then
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
                    elseif trace_details then
                        report("%s %s %a in category %a for tag %a in dataset %a","unknown","entry",field,category,tag,name)
                    end
                elseif trace_details then
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
                    elseif trace_details then
                        report("%s %s %a in category %a for tag %a in dataset %a","unknown","field",field,category,tag,name)
                    end
                elseif trace_details then
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
                        elseif trace_details then
                            report("%s %s %a in category %a for tag %a in dataset %a","unknown","detail",field,category,tag,name)
                        end
                    elseif trace_details then
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
                elseif trace_details then
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

    implement { name = "btxfield",     actions = btxfield,  arguments = "3 strings" }
    implement { name = "btxdetail",    actions = btxdetail, arguments = "3 strings" }
    implement { name = "btxflush",     actions = btxflush,  arguments = "3 strings" }
    implement { name = "btxdirect",    actions = btxdirect, arguments = "3 strings" }

    implement { name = "btxfieldname", actions = { get, context }, arguments = { "string", "string", "string", false, false } }
    implement { name = "btxfieldtype", actions = { get, context }, arguments = { "string", "string", "string", true,  false } }
    implement { name = "btxfoundname", actions = { get, context }, arguments = { "string", "string", "string", false, true  } }
    implement { name = "btxfoundtype", actions = { get, context }, arguments = { "string", "string", "string", true,  true  } }

    implement { name = "btxdoifelse",  actions = { okay, ctx_doifelse }, arguments = "3 strings" }
    implement { name = "btxdoif",      actions = { okay, ctx_doif     }, arguments = "3 strings" }
    implement { name = "btxdoifnot",   actions = { okay, ctx_doifnot  }, arguments = "3 strings" }

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
        CONTEXTLMTXMODE > 0 and "symb-imp-%s.mklx" or "",
        CONTEXTLMTXMODE > 0 and "symb-imp-%s.mkxl" or "",
        "publ-imp-%s.mkvi",
        "publ-imp-%s.mkiv",
        "publ-imp-%s.tex",
    }

    local function failure(name)
        report("unknown library %a",name)
    end

    local function action(name,foundname)
        context.loadfoundpublicationfile(name,foundname)
    end

    function publications.loaddefinitionfile(name) -- a more specific name
        resolvers.uselibrary {
            name     = gsub(name,"^publ%-",""),
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
        resolvers.uselibrary {
            name     = gsub(name,"^publ%-",""),
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

local renderings = { } --- per dataset

do

    publications.lists = publications.lists or { }
    local lists        = publications.lists

    local context     = context
    local structures  = structures

    local references  = structures.references
    local sections    = structures.sections

    -- per rendering

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

    -- tag | listindex | reference | userdata | dataindex

    local methods = { }
    lists.methods = methods

    methods[v_dataset] = function(dataset,rendering,keyword)
        local current = datasets[dataset]
        local luadata = current.luadata
        local list    = rendering.list
        for tag, data in sortedhash(luadata) do
            if not keyword or validkeyword(dataset,tag,keyword) then
                local index = data.index or 0
                list[#list+1] = { tag, index, 0, false, index }
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
            local u = r.userdata -- better check on metadata.kind == "btx"
            if u then
                local set = u.btxset or v_default
                if set == dataset then
                    local tag = u.btxref
                    if tag and (not keyword or validkeyword(dataset,tag,keyword)) then
                        local data = luadata[tag]
                        list[#list+1] = { tag, listindex, 0, u, data and data.index or 0 }
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
            if u then -- better check on metadata.kind == "btx"
                local set = u.btxset or v_default
                if set == dataset then
-- inspect(structures.references.internals[tonumber(u.btxint)])
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
                                l[#l+1] = u.btxint -- tonumber ?
                            else
                                local data = luadata[tag]
                                local l = { tag, listindex, 0, u, data and data.index or 0 }
                                list[#list+1] = l
                                traced[tag] = l
                            end
                        else
                            done[tag]    = section
                            alldone[tag] = true
                            local data = luadata[tag]
                            list[#list+1] = { tag, listindex, 0, u, data and data.index or 0 }
                        end
                    end
                    if tag then
                        registerpage(pages,tag,result,listindex)
                    end
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
        local filter             = specification.filter or ""
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
        report_list("collecting entries using method %a and sort order %a",method,rendering.sorttype)
        lists.result  = { } -- kind of reset
        local keyword = specification.keyword
        if keyword and keyword ~= "" then
            keyword = settings_to_set(keyword)
        else
            keyword = nil
        end
        filtermethod(dataset,rendering,keyword)
        local list = rendering.list
        if list and filter ~= "" then
            local find = publications.finder(dataset,filter)
            if find then
                local luadata = datasets[dataset].luadata
                local matched = 0
                for i=1,#list do
                    local found = list[i]
                    local entry = luadata[found[1]]
                    if find(entry) then
                        matched = matched + 1
                        list[matched] = found
                    end
                end
                for i=#list,matched + 1,-1 do
                    list[i] = nil
                end
            end
        end
        ctx_btxsetnoflistentries(list and #list or 0)
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
                end
            end
        end
        if type(sorter) == "function" then
            list = sorter(dataset,rendering,newlist,sorttype) or newlist
        else
            list = newlist
        end
        local newlist        = { }
        local tagtolistindex = { }
        rendering.tagtolistindex = tagtolistindex
        for i=1,#list do
            local li    = list[i]
            local tag   = li[1]
            local entry = luadata[tag]
            if entry then
                local detail = details[tag]
                if not detail then
                    -- fatal error
                    report("fatal error, missing details for tag %a in dataset %a (enhanced: %s)",tag,dataset,current.enhanced and "yes" or "no")
                 -- lastreferencenumber = lastreferencenumber + 1
                 -- details[tag] = { referencenumber = lastreferencenumber }
                 -- li[3] = lastreferencenumber
                 -- tagtolistindex[tag] = i
                 -- newlist[#newlist+1] = li
                elseif detail.parent then
                    -- skip this one
                else
                    local referencenumber = detail.referencenumber
                    if not referencenumber then
                        lastreferencenumber    = lastreferencenumber + 1
                        referencenumber        = lastreferencenumber
                        detail.referencenumber = lastreferencenumber
                    end
                    li[3] = referencenumber
                    tagtolistindex[tag] = i
                    newlist[#newlist+1] = li
                end
            end
        end
        groups[group] = lastreferencenumber
        rendering.list = newlist
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
            local first = r[1]
            local last  = r[2]
            ctx_btxsetfirstinternal(first[2].internal)
            ctx_btxsetfirstpage(first[1])
            if last then
                ctx_btxsetlastinternal(last[2].internal)
                ctx_btxsetlastpage(last[1])
            end
            if trace_details then
                report("expanding page setup")
            end
            ctx_btxpagesetup("") -- nothing yet
        end
    end

    implement {
        name      = "btxflushpages",
        arguments = "2 strings",
        actions   = btxflushpages,
    }

    local function identical(a,b)
        local na = #a
        local nb = #b
        if na ~= nb then
            return false
        end
        if na > 0 then
            for i=1,na do
                if not identical(a[i],b[i]) then
                    return false
                end
            end
            return true
        end
        local ha = a.hash
        local hb = b.hash
        if ha then
            return ha == hb
        end
        for k, v in next, a do
            if k == "original" or k == "snippets" then
                -- skip diagnostic info
            elseif v ~= b[k] then
                return false
            end
        end
        return true
    end

    function lists.sameasprevious(dataset,i,name,order,method)
        local rendering = renderings[dataset]
        local list      = rendering.list
        local n         = tonumber(i)
        if n and n > 1 and n <= #list then
            local luadata   = datasets[dataset].luadata
            local p_index   = list[n-1][1]
            local c_index   = list[n  ][1]
            local previous  = getdirect(dataset,luadata[p_index],name)
            local current   = getdirect(dataset,luadata[c_index],name)

            -- authors are a special case

          -- if not order then
          --    order = gettexcounter("c_btx_list_reference")
          -- end
            if order and order > 0 and (method == v_always or method == v_doublesided) then
                local clist = listtolist[order]
                local plist = listtolist[order-1]
                if clist and plist then
                    local crealpage = clist.references.realpage
                    local prealpage = plist.references.realpage
                    if crealpage ~= prealpage then
                        if method == v_always or not conditionals.layoutisdoublesided then
                            if trace_details then
                                report("previous %a, current %a, different page",previous,current)
                            end
                            return false
                        elseif crealpage % 2 == 0 then
                            if trace_details then
                                report("previous %a, current %a, different page",previous,current)
                            end
                            return false
                        end
                    end
                end
            end
            local sameentry = false
            if current and current == previous then
                sameentry = true
            else
                local p_casted = getcasted(dataset,p_index,name)
                local c_casted = getcasted(dataset,c_index,name)
                if c_casted and c_casted == p_casted then
                    sameentry = true
                elseif type(c_casted) == "table" and type(p_casted) == "table" then
                    sameentry = identical(c_casted,p_casted)
                end
            end
            if trace_details then
                if sameentry then
                    report("previous %a, current %a, same entry",previous,current)
                else
                    report("previous %a, current %a, different entry",previous,current)
                end
           end
            return sameentry
        else
            return false
        end
    end

    function lists.combiinlist(dataset,tag)
        local rendering = renderings[dataset]
        local list      = rendering.list
        local toindex   = rendering.tagtolistindex
        return toindex and toindex[tag]
    end

    function lists.flushcombi(dataset,tag)
        local rendering = renderings[dataset]
        local list      = rendering.list
        local toindex   = rendering.tagtolistindex
        local listindex = toindex and toindex[tag]
        if listindex then
            local li = list[listindex]
            if li then
                local data      = datasets[dataset]
                local luadata   = data.luadata
                local details   = data.details
                local tag       = li[1]
                local listindex = li[2]
                local n         = li[3]
                local entry     = luadata[tag]
                local detail    = details[tag]
                ctx_btxstartcombientry()
                ctx_btxsetcurrentlistindex(listindex)
                ctx_btxsetcategory(entry.category or "unknown")
                ctx_btxsettag(tag)
                ctx_btxsetnumber(n)
                local language = entry.language
                if language then
                    ctx_btxsetlanguage(language)
                end
                local authorsuffix = detail.authorsuffix
                if authorsuffix then
                    ctx_btxsetsuffix(authorsuffix)
                end
                ctx_btxhandlecombientry()
                ctx_btxstopcombientry()
            end
        end
    end

    function lists.flushtag(dataset,i)
        local li = renderings[dataset].list[i]
        ctx_btxsettag(li and li[1] or "")
    end

    function lists.flushentry(dataset,i)
        local rendering = renderings[dataset]
        local list      = rendering.list
        local li        = list[i]
        if li then
            local data      = datasets[dataset]
            local luadata   = data.luadata
            local details   = data.details
            local tag       = li[1]
            local listindex = li[2]
            local n         = li[3]
            local entry     = luadata[tag]
            local detail    = details[tag]
            --
            ctx_btxstartlistentry()
            ctx_btxsetcurrentlistentry(i) -- redundant
            ctx_btxsetcurrentlistindex(listindex or 0)
            local children = detail.children
            local language = entry.language
            if children then
                ctx_btxsetcombis(concat(children,","))
            end
            ctx_btxsetcategory(entry.category or "unknown")
            ctx_btxsettag(tag)
            ctx_btxsetnumber(n)
            --
            local citation = citetolist[n]
            if citation then
                local references = citation.references
                if references then
                    local internal = references.internal
                    if internal and internal > 0 then
                        ctx_btxsetinternal(internal)
                    end
                end
            end
            --
            if language then
                ctx_btxsetlanguage(language)
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
                local bl = userdata.btxint
                if bl and bl ~= "" then
                    ctx_btxsetbacklink(bl)
                end
            end
            local authorsuffix = detail.authorsuffix
            if authorsuffix then
                ctx_btxsetsuffix(authorsuffix)
            end
            rendering.userdata = userdata
            ctx_btxhandlelistentry()
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
        arguments = "2 strings",
        actions   = { getuserdata, context },
    }

    implement {
        name      = "btxdoifelseuservariable",
        arguments = "2 strings",
        actions   = { getuserdata, ctx_doifelse },
    }

 -- implement {
 --     name      = "btxresolvelistreference",
 --     arguments = "2 strings",
 --     actions   = lists.resolve,
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
                { "filter" },
            }
        }
    }

    implement {
        name      = "btxpreparelistentries",
        arguments = "string",
        actions   = lists.prepareentries,
    }

    implement {
        name      = "btxfetchlistentries",
        arguments = "string",
        actions   = lists.fetchentries,
    }

    implement {
        name      = "btxflushlistentry",
        arguments = { "string", "integer" },
        actions   = lists.flushentry,
    }

    implement {
        name      = "btxflushlisttag",
        arguments = { "string", "integer" },
        actions   = lists.flushtag,
    }

    implement {
        name      = "btxflushlistcombi",
        arguments = "2 strings",
        actions   = lists.flushcombi,
    }

    implement {
        name      = "btxdoifelsesameasprevious",
        actions   = { lists.sameasprevious, ctx_doifelse },
        arguments = { "string", "integer", "string", "integer", "string" }
    }

    implement {
        name      = "btxdoifelsecombiinlist",
        arguments = "2 strings",
        actions   = { lists.combiinlist, ctx_doifelse },
    }

end

do

    local citevariants        = { }
    publications.citevariants = citevariants

    local function btxvalidcitevariant(dataset,variant)
        local citevariant = rawget(citevariants,variant)
        if citevariant then
            return citevariant
        end
        local s = datasets[dataset]
        if s then
            s = s.specifications
        end
        if s then
            for k, v in sortedhash(s) do
                s = k
                break
            end
        end
        if s then
            s = specifications[s]
        end
        if s then
            s = s.types
        end
        if s then
            variant = s[variant]
            if variant then
                citevariant = rawget(citevariants,variant)
            end
            if citevariant then
                return citevariant
            end
        end
        return citevariants.default
    end

    local function btxhandlecite(specification)
        local dataset   = specification.dataset or v_default
        local reference = specification.reference
        local variant   = specification.variant
        --
        if not variant or variant == "" then
            variant = "default"
        end
        if not reference or reference == "" then
            return
        end
        --
        local data = datasets[dataset]
        if not data.suffixed then
            data.authorconversion = specification.authorconversion
            publications.enhancers.suffixes(data)
        end
        --
        specification.variant   = variant
        specification.compress  = specification.compress
        specification.markentry = specification.markentry ~= false
        --
        if specification.sorttype == v_yes then
            specification.sorttype = v_normal
        end
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
        local citevariant = btxvalidcitevariant(dataset,variant)
        --
        citevariant(specification) -- we always fall back on default
    end

    local function btxhandlenocite(specification)
        if trialtypesetting() then
            return
        end
        local dataset   = specification.dataset or v_default
        local reference = specification.reference
        if not reference or reference == "" then
            return
        end
        --
        local method   = specification.method
        local internal = specification.internal or ""
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
        if todo then
            marked_todo    = todo
            marked_dataset = dataset
            marked_list    = list
            marked_method  = method
            btxflushmarked() -- here (could also be done in caller)
        else
            marked_todo = false
        end
    end

    implement {
        name      = "btxhandlecite",
        actions   = btxhandlecite,
        arguments = {
            {
                { "dataset" },
                { "reference" },
                { "method" },
                { "variant" },
                { "sorttype" },
                { "compress" },
                { "authorconversion" },
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
                { "method" },
            }
        }
    }

    -- sorter

    local keysorter = function(a,b)
        local ak = a.sortkey
        local bk = b.sortkey
        if ak == bk then
            local as = a.suffix -- numeric
            local bs = b.suffix -- numeric
            if as and bs then
                return (as or 0) < (bs or 0)
            else
                return false
            end
        else
            return ak < bk
        end
    end

    local revsorter = function(a,b)
        return keysorter(b,a)
    end

    local function compresslist(source,specification)
        if specification.sorttype == v_normal then
            sort(source,keysorter)
        elseif specification.sorttype == v_reverse then
            sort(source,revsorter)
        end
        if specification and specification.compress == v_yes and specification.numeric then
            local first, last, firstr, lastr
            local target, noftarget, tags = { }, 0, { }
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
                local entry   = source[i]
                local current = entry.sortkey -- so we need a sortkey !
                if type(current) == "number" then
                    if entry.suffix then
                        if not first then
                            first, last, firstr, lastr = current, current, entry, entry
                        else
                            flushrange()
                            first, last, firstr, lastr = current, current, entry, entry
                        end
                    else
                        if not first then
                            first, last, firstr, lastr = current, current, entry, entry
                        elseif current == last + 1 then
                            last, lastr = current, entry
                        else
                            flushrange()
                            first, last, firstr, lastr = current, current, entry, entry
                        end
                    end
                    tags[#tags+1] = entry.tag
                end
            end
            if first and last then
                flushrange()
            end
            return target
        else
            local target, noftarget = { }, 0
            for i=1,#source do
                local entry = source[i]
                noftarget   = noftarget + 1
                target[noftarget] = {
                    first = entry,
                    tags  = { entry.tag },
                }
            end
            return target
        end
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
        local sorttype   = specification.sorttype
        local getter     = specification.getter
        local setter     = specification.setter
        local compressor = specification.compressor
        local method     = specification.method
        local varfield   = specification.varfield
        --
        local reference  = publications.parenttag(dataset,reference)
        --
        local found, todo, list = findallused(dataset,reference,internal,method == v_text or method == v_always) -- also when not in list
        --
        if not found or #found == 0 then
--         if not list or #list == 0 then
            report("no entry %a found in dataset %a",reference,dataset)
        elseif not setup then
            report("invalid reference for %a",reference)
        else
            if trace_cite then
                report("processing reference %a",reference)
            end
            local source  = { }
            local luadata = datasets[dataset].luadata
            for i=1,#found do
                local entry      = found[i]
                local userdata   = entry.userdata
                local references = entry.references
                local tag        = userdata and userdata.btxref or entry.tag -- no need for userdata
                if tag then
                    local ldata = luadata[tag]
                    local data  = {
                        internal  = references and references.internal,
                        language  = ldata.language,
                        dataset   = dataset,
                        tag       = tag,
                        varfield  = varfield,
                     -- combis    = entry.userdata.btxcom,
                     -- luadata   = ldata,
                    }
                    setter(data,dataset,tag,entry)
                    if type(data) == "table" then
                        source[#source+1] = data
                    else
                        report("error in cite rendering %a",setup or "?")
                    end
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

            local function flush(i,n,entry,last)
                local tag = entry.tag
                local currentcitation = markcite(dataset,tag)
                --
                ctx_btxstartcite()
                ctx_btxsettag(tag)
                ctx_btxsetcategory(entry.category or "unknown")
                --
                local language = entry.language
                if language then
                    ctx_btxsetlanguage(language)
                end
                --
                if lefttext  then local text = lefttext [i] ; if text and text ~= "" then ctx_btxsetlefttext (text) end end
                if righttext then local text = righttext[i] ; if text and text ~= "" then ctx_btxsetrighttext(text) end end
                if before    then local text = before   [i] ; if text and text ~= "" then ctx_btxsetbefore   (text) end end
                if after     then local text = after    [i] ; if text and text ~= "" then ctx_btxsetafter    (text) end end
                --
                if method ~= v_text then
                    ctx_btxsetbacklink(currentcitation)
                    local bl = listtocite[currentcitation]
                    if bl then
                        -- we refer to a coming list entry
                        bl = bl.references.internal
                    else
                        -- we refer to a previous list entry
                        bl = entry.internal
                    end
                    ctx_btxsetinternal(bl and bl > 0 and bl or "")
                end
                local language = entry.language
                if language then
                    ctx_btxsetlanguage(language)
                end
             -- local combis = entry.combis
             -- if combis then
             --     ctx_btxsetcombis(combis)
             -- end
                if not getter(entry,last,nil,specification) then
                    ctx_btxsetfirst("") -- (f_missing(tag))
                end
                ctx_btxsetconcat(concatstate(i,n))
                if trace_details then
                    report("expanding cite setup %a",setup)
                end
                ctx_btxcitesetup(setup)
                ctx_btxstopcite()
            end
            if sorttype == v_normal or sorttype == v_reverse then
                local target = (compressor or compresslist)(source,specification)
                local nofcollected = #target
                if nofcollected == 0 then
                    local nofcollected = #source
                    if nofcollected == 0 then
                        unknowncite(reference)
                    else
                        for i=1,nofcollected do
                            flush(i,nofcollected,source[i])
                        end
                    end
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
        if trialtypesetting() then
            marked_todo = false
        elseif method ~= v_text then
            marked_todo    = todo
            marked_dataset = dataset
            marked_list    = list
            marked_method  = method
            btxflushmarked() -- here (could also be done in caller)
        else
            marked_todo = false
        end
    end

    --

    local function simplegetter(first,last,field,specification)
        local value = first[field]
        if value then
            if type(value) == "string" then
                ctx_btxsetfirst(value)
                if last then
                    ctx_btxsetsecond(last[field])
                end
                return true
            else
                report("missing data type definition for %a",field)
            end
        end
    end

    local setters = setmetatableindex({},function(t,k)
        local v = function(data,dataset,tag,entry)
            local value  = getcasted(dataset,tag,k)
            data.value   = value -- not really needed
            data[k]      = value
            data.sortkey = value
            data.sortfld = k
        end
        t[k] = v
        return v
    end)

    local getters = setmetatableindex({},function(t,k)
        local v = function(first,last,_,specification)
            return simplegetter(first,last,k,specification) -- maybe _ or k
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

    -- category

    do

        local function setter(data,dataset,tag,entry)
            data.category = getfield(dataset,tag,"category")
        end

        local function getter(first,last,_,specification)
            return simplegetter(first,last,"category",specification)
        end

        function citevariants.category(presets)
            processcite(presets,{
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

        local function getter(first,last,_,specification) -- last not used
            ctx_btxsetfirst(first.tag)
        end

        function citevariants.entry(presets)
            processcite(presets,{
                compress = false,
                setter   = setter,
                getter   = getter,
            })
        end

    end

    -- short

    do

        local function setter(data,dataset,tag,entry)
            local short  = getdetail(dataset,tag,"shorthash")
            local suffix = getdetail(dataset,tag,"shortsuffix")
            data.short   = short
            data.sortkey = short
            data.suffix  = suffix
        end

        local function getter(first,last,_,specification) -- last not used
            local short = first.short
            if short then
                local suffix = first.suffix
                ctx_btxsetfirst(short)
                if suffix then
                    ctx_btxsetsuffix(suffix) -- watch out: third
                end
                return true
            end
        end

        function citevariants.short(presets)
            processcite(presets,{
                setter = setter,
                getter = getter,
            })
        end

    end

    -- pages (no compress)

    do

        local function setter(data,dataset,tag,entry)
            data.pages = getcasted(dataset,tag,"pages")
        end

        local function getter(first,last,_,specification)
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
                setter = setter,
                getter = getter,
            })
        end

    end

    -- num

    do

        local function setter(data,dataset,tag,entry)
            local entries = entry.entries
            local text    = entries and entries.text or "?"
            data.num      = text
            data.sortkey  = tonumber(text) or text
        end

        local function getter(first,last,tag,specification)
            return simplegetter(first,last,"num",specification)
        end

        function citevariants.num(presets)
            processcite(presets,{
                numeric = true,
                setter  = setter,
                getter  = getter,
            })
        end

        citevariants.textnum = citevariants.num -- should not be needed

    end

    -- year

    do

        local function setter(data,dataset,tag,entry)
            local year   = getfield (dataset,tag,"year")
            local suffix = getdetail(dataset,tag,"authorsuffix")
            data.year    = year
            data.suffix  = suffix
            data.sortkey = tonumber(year) or 9999
        end

        local function getter(first,last,_,specification)
            return simplegetter(first,last,"year",specification)
        end

        function citevariants.year(presets)
            processcite(presets,{
                numeric = true,
                setter  = setter,
                getter  = getter,
            })
        end

    end

    -- index

    do

        local function setter(data,dataset,tag,entry)
            local index  = getfield(dataset,tag,"index")
            data.index   = index
            data.sortkey = index
        end

        local function getter(first,last,_,specification)
            return simplegetter(first,last,"index",specification)
        end

        function citevariants.index(presets)
            processcite(presets,{
                setter  = setter,
                getter  = getter,
                numeric = true,
            })
        end

    end

    -- tag

    do

        local function setter(data,dataset,tag,entry)
            data.tag     = tag
            data.sortkey = tag
        end

        local function getter(first,last,_,specification)
            return simplegetter(first,last,"tag",specification)
        end

        function citevariants.tag(presets)
            return processcite(presets,{
                setter = setter,
                getter = getter,
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

        local function getter(first,last,_,specification)
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

        -- is this good enough?

        local keysorter = function(a,b)
            local ak = a.authorhash
            local bk = b.authorhash
            if ak == bk then
                local as = a.authorsuffix -- numeric
                local bs = b.authorsuffix -- numeric
                if as and bs then
                    return (as or 0) < (bs or 0)
                else
                    return false
                end
            elseif ak and bk then
                return ak < bk
            else
                return false
            end
        end

        local revsorter = function(a,b)
            return keysorter(b,a)
        end

        local function authorcompressor(found,specification)
            -- HERE
            if specification.sorttype == v_normal then
                sort(found,keysorter)
            elseif specification.sorttype == v_reverse then
                sort(found,revsorter)
            end
            local result  = { }
            local entries = { }
            for i=1,#found do
                local entry  = found[i]
                local author = entry.authorhash
                if author then
                    local aentries = entries[author]
                    if aentries then
                        aentries[#aentries+1] = entry
                    else
                        entries[author] = { entry }
                    end
                end
            end
            -- beware: we use tables as hash so we get a cycle when inspecting (unless we start
            -- hashing with strings)
            for i=1,#found do
                local entry  = found[i]
                local author = entry.authorhash
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
                        local last   = entry.last
                        local value  = last and last[key]
                        if value then
                            ctx_btxsetsecond(value)
                        end
                        if suffix then
                            ctx_btxsetsuffix(suffix)
                        end
                    else
                        local suffix = entry.suffix
                        local value  = entry[key] or "" -- f_missing(tag)
                        ctx_btxsetfirst(value)
                        if suffix then
                            ctx_btxsetsuffix(suffix)
                        end
                    end
                    ctx_btxsetconcat(concatstate(i,nofcollected))
                    if trace_details then
                        report("expanding %a cite setup %a","multiple author",setup)
                    end
                    ctx_btxsubcitesetup(setup)
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
            ctx_btxsetfirst(entry[key] or "") -- f_missing(tag)
            if suffix then
                ctx_btxsetsuffix(entry.suffix)
            end
            if trace_details then
                report("expanding %a cite setup %a","single author",setup)
            end
            ctx_btxcitesetup(setup)
            ctx_btxstopciteauthor()
            ctx_btxstopsubcite()
        end

        local partialinteractive = false

        local currentbtxciteauthor = function()
            context.currentbtxciteauthorbyfield()
            return true -- needed?
        end

        local function authorgetter(first,last,key,specification) -- only first
            ctx_btxsetauthorfield(first.varfield or "author")
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
                local c = compresslist(entries,specification)
                local f = function() authorconcat(c,key,specification.setup or "author") return true end -- indeed return true?
                ctx_btxsetcount(#c)
                ctx_btxsetsecond(f)
            elseif first then
                -- happens with num
                local f = function() authorsingle(first,key,specification.setup or "author") return true end -- indeed return true?
                ctx_btxsetcount(0)
                ctx_btxsetsecond(f)
            end
            return true
        end

        -- author (the varfield hack is for editor and translator i.e author type)

        local function setter(data,dataset,tag,entry)
            data.author, data.field, data.type = getcasted(dataset,tag,data.varfield or "author")
            data.sortkey = text and lpegmatch(numberonly,text)
            data.authorhash = getdetail(dataset,tag,"authorhash") -- todo let getcasted return
        end

        local function getter(first,last,_,specification)
            ctx_btxsetauthorfield(specification.varfield or "author")
            if first.type == "author" then
                ctx_btxsetfirst(currentbtxciteauthor) -- formatter (much slower)
            else
                ctx_btxsetfirst(first.author)         -- unformatted
            end
            return true
        end

        function citevariants.author(presets)
            processcite(presets,{
                variant    = "author",
                setup      = "author",
                setter     = setter,
                getter     = getter,
                varfield   = presets.variant or "author",
                compressor = authorcompressor,
            })
        end

        -- authornum

        local function setter(data,dataset,tag,entry)
            local entries = entry.entries
            local text    = entries and entries.text or "?"
            data.author, data.field, data.type = getcasted(dataset,tag,"author")
            data.authorhash = getdetail(dataset,tag,"authorhash") -- todo let getcasted return
            data.num     = text
            data.sortkey = text and lpegmatch(numberonly,text)
        end

        local function getter(first,last,_,specification)
            authorgetter(first,last,"num",specification)
            return true
        end

        function citevariants.authornum(presets)
            processcite(presets,{
                variant    = "authornum",
                setup      = "author:num",
                numeric    = true,
                setter     = setter,
                getter     = getter,
                compressor = authorcompressor,
            })
        end

        -- authoryear | authoryears

        local function setter(data,dataset,tag,entry)
            data.author, data.field, data.type = getcasted(dataset,tag,"author")
            data.authorhash = getdetail(dataset,tag,"authorhash") -- todo let getcasted return
            local year   = getfield (dataset,tag,"year")
            local suffix = getdetail(dataset,tag,"authorsuffix")
            data.year    = year
            data.suffix  = suffix
            data.sortkey = tonumber(year) or 9999
        end

        local function getter(first,last,_,specification)
            authorgetter(first,last,"year",specification)
            return true
        end

        function citevariants.authoryear(presets)
            processcite(presets,{
                variant    = "authoryear",
                setup      = "author:year",
                numeric    = true,
                setter     = setter,
                getter     = getter,
                compressor = authorcompressor,
            })
        end

        local function getter(first,last,_,specification)
            authorgetter(first,last,"year",specification)
            return true
        end

        function citevariants.authoryears(presets)
            processcite(presets,{
                variant    = "authoryears",
                setup      = "author:years",
                numeric    = true,
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
            listindex = tonumber(listindex)
            if listindex then
                action(dataset,block,tag,variant,listindex)
            end
        end
    end

    implement {
        name      = "btxlistvariant",
        arguments = "5 strings",
        actions   = btxlistvariant,
    }

    function listvariants.default(dataset,block,tag,variant)
        ctx_btxsetfirst("?")
        if trace_details then
            report("expanding %a list setup %a","default",variant)
        end
        ctx_btxnumberingsetup("default")
    end

    function listvariants.num(dataset,block,tag,variant,listindex)
        ctx_btxsetfirst(listindex)
        if trace_details then
            report("expanding %a list setup %a","num",variant)
        end
        ctx_btxnumberingsetup(variant or "num")
    end

 -- listvariants[v_yes] = listvariants.num

    function listvariants.index(dataset,block,tag,variant,listindex)
        local index = getdetail(dataset,tag,"index")
        ctx_btxsetfirst(index or "?")
        if trace_details then
            report("expanding %a list setup %a","index",variant)
        end
        ctx_btxnumberingsetup(variant or "index")
    end

    function listvariants.tag(dataset,block,tag,variant,listindex)
        ctx_btxsetfirst(tag)
        if trace_details then
            report("expanding %a list setup %a","tag",variant)
        end
        ctx_btxnumberingsetup(variant or "tag")
    end

    function listvariants.short(dataset,block,tag,variant,listindex)
        local short  = getdetail(dataset,tag,"shorthash")
        local suffix = getdetail(dataset,tag,"shortsuffix")
        if short then
            ctx_btxsetfirst(short)
        end
        if suffix then
            ctx_btxsetsuffix(suffix)
        end
        if trace_details then
            report("expanding %a list setup %a","short",variant)
        end
        ctx_btxnumberingsetup(variant or "short")
    end

end

-- a helper

do

 -- local context   = context
 -- local lpegmatch = lpeg.match
    local splitter  = lpeg.tsplitat(":")

    implement {
        name      = "checkinterfacechain",
        arguments = "2 strings",
        actions   = function(str,command)
            local chain = lpegmatch(splitter,str)
            if #chain > 0 then
                local command = context[command]
                local parent  = ""
                local child   = chain[1]
                command(child,parent)
                for i=2,#chain do
                    parent = child
                    child  = child .. ":" .. chain[i]
                    command(child,parent)
                end
            end
        end
    }

end

do

    local btxstring = ""

    implement {
        name    = "btxcmdstring",
        actions = function() if btxstring ~= "" then context(btxstring) end end,
    }

    function publications.prerollcmdstring(str)
        btxstring = str or ""
        tex.runtoks("t_btx_cmd")
        return nodes.toutf(tex.getbox("b_btx_cmd").list) or str
    end

end
