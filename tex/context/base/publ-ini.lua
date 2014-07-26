if not modules then modules = { } end modules ['publ-ini'] = {
    version   = 1.001,
    comment   = "this module part of publication support",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- If we define two datasets with the same bib file we can consider
-- sharing the data but that means that we need to have a parent which
-- in turn makes things messy if we start manipulating entries in
-- different ways (future) .. not worth the trouble as we will seldom
-- load big bib files many times and even then ... fonts are larger.

local next, rawget, type, tostring, tonumber = next, rawget, type, tostring, tonumber
local match, gmatch, format, gsub, find = string.match, string.gmatch, string.format, string.gsub, string.find
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

local report             = logs.reporter("publications")
local report_cite        = logs.reporter("publications","cite")
local report_reference   = logs.reporter("publications","reference")

local trace              = false  trackers.register("publications",                 function(v) trace            = v end)
local trace_cite         = false  trackers.register("publications.cite",            function(v) trace_cite       = v end)
local trace_missing      = false  trackers.register("publications.cite.missing",    function(v) trace_missing    = v end)
local trace_references   = false  trackers.register("publications.cite.references", function(v) trace_references = v end)

local datasets           = publications.datasets
local writers            = publications.writers

local variables          = interfaces.variables

local v_local            = variables["local"]
local v_global           = variables["global"]

local v_force            = variables.force
local v_standard         = variables.standard
local v_start            = variables.start
local v_none             = variables.none
local v_left             = variables.left
local v_right            = variables.right
local v_middle           = variables.middle
local v_inbetween        = variables.inbetween
local v_yes              = variables.yes
local v_all              = variables.all
local v_short            = variables.short
local v_cite             = variables.cite
local v_default          = variables.default
local v_reference        = variables.reference
local v_dataset          = variables.dataset
local v_author           = variables.author or "author"
local v_editor           = variables.editor or "editor"

local numbertochar       = converters.characters

local logsnewline        = logs.newline
local logspushtarget     = logs.pushtarget
local logspoptarget      = logs.poptarget
local csname_id          = token.csname_id

local basicsorter        = sorters.basicsorter -- (a,b)
local sortcomparer       = sorters.comparers.basic -- (a,b)
local sortstripper       = sorters.strip
local sortsplitter       = sorters.splitters.utf

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

local ctx_setvalue                = context.setvalue
local ctx_firstoftwoarguments     = context.firstoftwoarguments
local ctx_secondoftwoarguments    = context.secondoftwoarguments
local ctx_firstofoneargument      = context.firstofoneargument
local ctx_gobbleoneargument       = context.gobbleoneargument

local ctx_btxlistparameter        = context.btxlistparameter
local ctx_btxcitevariantparameter = context.btxcitevariantparameter
local ctx_btxlistvariantparameter = context.btxlistvariantparameter
local ctx_btxdirectlink           = context.btxdirectlink
local ctx_btxhandlelistentry      = context.btxhandlelistentry
local ctx_btxchecklistentry       = context.btxchecklistentry
local ctx_btxchecklistcombi       = context.btxchecklistcombi
local ctx_btxsetcitereference     = context.btxsetcitereference
local ctx_btxsetlistreference     = context.btxsetlistreference
local ctx_btxmissing              = context.btxmissing

local ctx_btxsetdataset           = context.btxsetdataset
local ctx_btxsettag               = context.btxsettag
local ctx_btxsetnumber            = context.btxsetnumber
local ctx_btxsetlanguage          = context.btxsetlanguage
local ctx_btxsetcombis            = context.btxsetcombis
local ctx_btxsetcategory          = context.btxsetcategory
local ctx_btxcitesetup            = context.btxcitesetup
local ctx_btxsetfirst             = context.btxsetfirst
local ctx_btxsetsecond            = context.btxsetsecond
local ctx_btxsetinternal          = context.btxsetinternal
local ctx_btxsetbacklink          = context.btxsetbacklink
local ctx_btxsetbacktrace         = context.btxsetbacktrace
local ctx_btxsetcount             = context.btxsetcount
local ctx_btxsetconcat            = context.btxsetconcat
local ctx_btxsetoveflow           = context.btxsetoverflow
local ctx_btxstartcite            = context.btxstartcite
local ctx_btxstopcite             = context.btxstopcite
local ctx_btxstartciteauthor      = context.btxstartciteauthor
local ctx_btxstopciteauthor       = context.btxstopciteauthor
local ctx_btxstartsubcite         = context.btxstartsubcite
local ctx_btxstopsubcite          = context.btxstopsubcite
local ctx_btxlistsetup            = context.btxlistsetup

statistics.register("publications load time", function()
    local publicationsstats = publications.statistics
    local nofbytes = publicationsstats.nofbytes
    if nofbytes > 0 then
        return string.format("%s seconds, %s bytes, %s definitions, %s shortcuts",
            statistics.elapsedtime(publications),nofbytes,publicationsstats.nofdefinitions,publicationsstats.nofshortcuts)
    else
        return nil
    end
end)

luatex.registerstopactions(function()
    local done = false
    local undefined = csname_id("undefined*crap")
    for name, dataset in sortedhash(datasets) do
        for command, n in sortedhash(dataset.commands) do
            if not done then
                logspushtarget("logfile")
                logsnewline()
                report("start used btx commands")
                logsnewline()
                done = true
            end
            local c = csname_id(command)
            if c and c ~= undefined then
                report("%-20s %-20s % 5i %s",name,command,n,"known")
            else
                local u = csname_id(utf.upper(command))
                if u and u ~= undefined then
                    report("%-20s %-20s % 5i %s",name,command,n,"KNOWN")
                else
                    report("%-20s %-20s % 5i %s",name,command,n,"unknown")
                end
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

-- we use a a dedicated (and efficient as it know what it deals with) serializer,
-- also because we need to ignore the 'details' field

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
        local loaded = dataset.loaded
        local sources = dataset.sources
        local used   = { }
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
                publications.load(dataset,filename,"previous")
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

if not publications.authors then
    initializer() -- for now, runtime loaded
end

-- we want to minimize references as there can be many (at least
-- when testing)

local initialized  = false
local usedentries  = { }
local citetolist   = { }
local listtocite   = { }
local nofcitations = 0

setmetatableindex(usedentries,function(t,k)
    if not initialized then
        usedentries = { }
        citetolist  = { }
        listtocite  = { }
        local internals = structures.references.internals
        local p_collect = (C(R("09")^1) * Carg(1) / function(s,entry) listtocite[tonumber(s)] = entry end + P(1))^0
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
                            local set = userdata.btxset
                            if set then
                                local tag = userdata.btxref
                                local s = usedentries[set]
                                if s then
                                    local u = s[tag]
                                    if u then
                                        u[#u+1] = entry
                                    else
                                        s[tag] = { entry }
                                    end
                                else
                                    usedentries[set] = { [tag] = { entry } }
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
                            end
                        end
                    elseif kind == "userdata" then
                        -- list entry (each cite)
                        local userdata = entry.userdata
                        if userdata then
                            local int = tonumber(userdata.btxint)
                            if int then
                                citetolist[int] = entry
-- xx[dataset][tag] = { entry, ...  }
                            end
                        end
                    end
                end
            else
                -- weird
            end
        end
        return usedentries[k]
    end
end)

-- match:
--
-- [current|previous|following] section
-- [current|previous|following] block
-- [current|previous|following] component
--
-- by prefix
-- by dataset

local reported = { }
local finder   = publications.finder

local function findallused(dataset,reference,internal)
    local finder  = publications.finder -- for the moment, not yet in all betas
    local find    = finder and finder(reference)
    local tags    = not find and settings_to_array(reference)
    local todo    = { }
    local okay    = { } -- only if mark
    local set     = usedentries[dataset]
    local valid   = datasets[dataset].luadata
    local ordered = datasets[dataset].ordered
    if set then
        local function register(tag)
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
        if find then
            tags = { }
            for i=1,#ordered do
                local entry = ordered[i]
                if find(entry) then
                    local tag = entry.tag
                    register(tag)
                    tags[#tags+1] = tag
                end
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
                    tags[#tags+1] = entry.tag
                end
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

local function unknowncite(reference)
    ctx_btxsettag(reference)
    ctx_btxcitesetup("unknown")
end

local concatstate = publications.concatstate

local tobemarked = nil

function marknocite(dataset,tag,nofcitations) -- or just: ctx_btxdomarkcitation
    ctx_btxstartcite()
    ctx_btxsetdataset(dataset)
    ctx_btxsettag(tag)
    ctx_btxsetbacklink(nofcitations)
    ctx_btxcitesetup("nocite")
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
            marknocite(dataset,tag,nofcitations)
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

function commands.flushmarked()
    if marked_list and tobemarked then
        for i=1,#marked_list do
            -- keep order
            local tag = marked_list[i]
            local tbm = tobemarked[tag]
            if not tbm or tbm == true then
                nofcitations = nofcitations + 1
                marknocite(marked_dataset,tag,nofcitations)
                if trace_cite then
                    report_cite("mark, dataset: %s, tag: %s, number: %s, state: %s",marked_dataset,tag,nofcitations,"unset")
                end
            else
            end
        end
    end
    tobemarked     = nil
    marked_dataset = nil
    marked_list    = nil
end

-- basic access

local function getfield(dataset,tag,name)
    local d = datasets[dataset].luadata[tag]
    return d and d[name]
end

local function getdetail(dataset,tag,name)
    local d = datasets[dataset].details[tag]
    return d and d[name]
end

function commands.btxsingularorplural(dataset,tag,name)
    local d = datasets[dataset].details[tag]
    if d then
        d = d[name]
    end
    if type(d) == "table" then
        d = #d <= 1
    else
        d = false
    end
    commands.doifelse(d)
end

function commands.oneorrange(dataset,tag,name)
    local d = datasets[dataset].luadata[tag] -- details ?
    if d then
        d = d[name]
    end
    if type(d) == "string" then
        d = find(d,"%-")
    else
        d = false

    end
    commands.doifelse(not d) -- so singular is default
end

function commands.firstinrange(dataset,tag,name)
    local d = datasets[dataset].luadata[tag] -- details ?
    if d then
        d = d[name]
    end
    if type(d) == "string" then
        context(match(d,"([^%-]+)"))
    end
end

-- basic loading

function commands.usebtxdataset(name,filename)
    publications.load(datasets[name],filename,"current")
end

function commands.convertbtxdatasettoxml(name,nice)
    publications.converttoxml(datasets[name],nice)
end

-- enhancing

local splitauthorstring = publications.authors.splitstring

local pagessplitter = lpeg.splitat(P("-")^1)

-- maybe not redo when already done

function publications.enhance(dataset) -- for the moment split runs (maybe publications.enhancers)
    statistics.starttiming(publications)
    if type(dataset) == "string" then
        dataset = datasets[dataset]
    end
    local luadata = dataset.luadata
    local details = dataset.details
    local ordered = dataset.ordered
    -- author, editor
    for tag, entry in next, luadata do
        local author = entry.author
        local editor = entry.editor
        details[tag] = {
            author = author and splitauthorstring(author),
            editor = editor and splitauthorstring(editor),
        }
    end
    -- short
    local shorts = { }
    for i=1,#ordered do
        local entry = ordered[i]
        if entry then
            local tag = entry.tag
            if tag then
                local detail = details[tag]
                if detail then
                    local author = detail.author
                    if author then
                        -- number depends on sort order
                        local t = { }
                        if #author == 0 then
                            -- what
                        else
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
                        local year = tonumber(entry.year) or 0
                        local short = formatters["%t%02i"](t,mod(year,100))
                        local s = shorts[short]
                        if not s then
                            shorts[short] = tag
                        elseif type(s) == "string" then
                            shorts[short] = { s, tag }
                        else
                            s[#s+1] = tag
                        end
                    else
                        --
                    end
                else
                    report("internal error, no detail for tag %s",tag)
                end
                --
                local pages = entry.pages
                if pages then
                    local first, last = lpegmatch(pagessplitter,pages)
                    details[tag].pages = first and last and { first, last } or pages
                end
                --
                local keyword = entry.keyword
                if keyword then
                    details[tag].keyword = settings_to_set(keyword)
                end
            else
                report("internal error, no tag at index %s",i)
            end
        else
            report("internal error, no entry at index %s",i)
        end
    end
    for short, tags in next, shorts do -- ordered ?
        if type(tags) == "table" then
            sort(tags)
            for i=1,#tags do
             -- details[tags[i]].short = short .. numbertochar(i)
                local detail = details[tags[i]]
                detail.short  = short
                detail.suffix = numbertochar(i)
            end
        else
            details[tags].short = short
        end
    end
    statistics.stoptiming(publications)
end

function commands.addbtxentry(name,settings,content)
    local dataset = datasets[name]
    if dataset then
        publications.addtexentry(dataset,settings,content)
    end
end

function commands.setbtxdataset(name,default)
    local dataset = rawget(datasets,name)
    if dataset then
        context(name)
    elseif default and default ~= "" then
        context(default)
    else
        context(v_standard)
        report("unknown dataset %a, forcing %a",name,standard)
    end
end

function commands.setbtxentry(name,tag)
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
end

-- rendering of fields

function commands.btxflush(name,tag,field)
    local dataset = rawget(datasets,name)
    if dataset then
        local fields = dataset.luadata[tag]
        if fields then
            local manipulator, field = splitmanipulation(field)
            local value = fields[field]
            if type(value) == "string" then
                local suffixes = dataset.suffixes[tag]
                if suffixes then
                    local suffix = suffixes[field]
                    if suffix then
                        value = value .. converters.characters(suffix)
                    end
                end
                context(manipulator and applymanipulation(manipulator,value) or value)
                return
            end
            local details = dataset.details[tag]
            if details then
                local value = details[field]
                if type(value) == "string" then
                    local suffixes = dataset.suffixes[tag]
                    if suffixes then
                        local suffix = suffixes[field]
                        if suffix then
                            value = value .. converters.characters(suffix)
                        end
                    end
                    context(manipulator and applymanipulation(manipulator,value) or value)
                    return
                end
            end
            report("unknown field %a of tag %a in dataset %a",field,tag,name)
        else
            report("unknown tag %a in dataset %a",tag,name)
        end
    else
        report("unknown dataset %a",name)
    end
end

function commands.btxdetail(name,tag,field)
    local dataset = rawget(datasets,name)
    if dataset then
        local details = dataset.details[tag]
        if details then
            local manipulator, field = splitmanipulation(field)
            local value = details[field]
            if type(value) == "string" then
                local suffixes = dataset.suffixes[tag]
                if suffixes then
                    local suffix = suffixes[field]
                    if suffix then
                        value = value .. converters.characters(suffix)
                    end
                end
                context(manipulator and applymanipulation(manipulator,value) or value)
            else
                report("unknown detail %a of tag %a in dataset %a",field,tag,name)
            end
        else
            report("unknown tag %a in dataset %a",tag,name)
        end
    else
        report("unknown dataset %a",name)
    end
end

function commands.btxfield(name,tag,field)
    local dataset = rawget(datasets,name)
    if dataset then
        local fields = dataset.luadata[tag]
        if fields then
            local manipulator, field = splitmanipulation(field)
            local value = fields[field]
            if type(value) == "string" then
                local suffixes = dataset.suffixes[tag]
                if suffixes then
                    local suffix = suffixes[field]
                    if suffix then
                        value = value .. converters.characters(suffix)
                    end
                end
                context(manipulator and applymanipulation(manipulator,value) or value)
            else
                report("unknown field %a of tag %a in dataset %a",field,tag,name)
            end
        else
            report("unknown tag %a in dataset %a",tag,name)
        end
    else
        report("unknown dataset %a",name)
    end
end

-- testing: to be speed up with testcase

function commands.btxdoifelse(name,tag,field)
    local dataset = rawget(datasets,name)
    if dataset then
        local data  = dataset.luadata[tag]
        local value = data and data[field]
        if value and value ~= "" then
            ctx_firstoftwoarguments()
            return
        end
    end
    ctx_secondoftwoarguments()
end

function commands.btxdoif(name,tag,field)
    local dataset = rawget(datasets,name)
    if dataset then
        local data  = dataset.luadata[tag]
        local value = data and data[field]
        if value and value ~= "" then
            ctx_firstofoneargument()
            return
        end
    end
    ctx_gobbleoneargument()
end

function commands.btxdoifnot(name,tag,field)
    local dataset = rawget(datasets,name)
    if dataset then
        local data  = dataset.luadata[tag]
        local value = data and data[field]
        if value and value ~= "" then
            ctx_gobbleoneargument()
            return
        end
    end
    ctx_firstofoneargument()
end

-- -- alternative approach: keep data at the tex end

function publications.singularorplural(singular,plural)
    if lastconcatsize and lastconcatsize > 1 then
        context(plural)
    else
        context(singular)
    end
end

local patterns = { "publ-imp-%s.mkvi", "publ-imp-%s.mkiv", "publ-imp-%s.tex" }

local function failure(name)
    report("unknown library %a",name)
end

local function action(name,foundname)
    context.input(foundname)
end

function commands.loadbtxdefinitionfile(name) -- a more specific name
    commands.uselibrary {
        name     = gsub(name,"^publ%-",""),
        patterns = patterns,
        action   = action,
        failure  = failure,
        onlyonce = true,
    }
end

-- lists:

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

-- local function sortedtags(dataset,list,sorttype)
--     local luadata = datasets[dataset].luadata
--     local valid = { }
--     for i=1,#list do
--         local tag = list[i]
--         local entry = luadata[tag]
--         if entry then
--             local key = entry[sorttype]
--             if key then
--                 valid[#valid+1] = {
--                     tag   = tag,
--                     split = sortsplitter(sortstripper(key))
--                 }
--             end
--         end
--     end
--     if #valid == 0 or #valid ~= #list then
--         return list
--     else
--         sorters.sort(valid,basicsorter)
--         for i=1,#valid do
--             valid[i] = valid[i].tag
--         end
--         return valid
--     end
-- end
--
--     if sorttype and sorttype ~= "" then
--         tags = sortedtags(dataset,tags,sorttype)
--     end

-- why shorts vs tags: only for sorting

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

local function validkeyword(dataset,tag,keyword)
    local ds = datasets[dataset]
    if not ds then
        report("unknown dataset %a",dataset)
        return
    end
    local dt = ds.details[tag]
    if not dt then
        report("no details for tag %a",tag)
        return
    end
    local kw = dt.keyword
    if kw then
        for k in next, keyword do
            if kw[k] then
                return true
            end
        end
    end
end

local methods = { }
lists.methods = methods

methods[v_dataset] = function(dataset,rendering,keyword)
    -- why only once inless criterium=all?
    local luadata = datasets[dataset].luadata
    local list = rendering.list
    for tag, data in sortedhash(luadata) do
        if not keyword or validkeyword(dataset,tag,keyword) then
            list[#list+1] = { tag, false, false, 0 }
        end
    end
end

methods[v_force] = function (dataset,rendering,keyword)
    -- only for checking, can have duplicates, todo: collapse page numbers, although
    -- we then also needs deferred writes
    local result = structures.lists.filter(rendering.specification) or { }
    local list   = rendering.list
    for listindex=1,#result do
        local r = result[listindex]
        local u = r.userdata
        if u and u.btxset == dataset then
            local tag = u.btxref
            if tag and (not keyword or validkeyword(dataset,tag,keyword)) then
                list[#list+1] = { tag, listindex, u.btxint, 0 }
            end
        end
    end
    lists.result = result
end

-- local  : if tag and                      done[tag] ~= section then ...
-- global : if tag and not alldone[tag] and done[tag] ~= section then ...

methods[v_local] = function(dataset,rendering,keyword)
    local result    = structures.lists.filter(rendering.specification) or { }
    local section   = sections.currentid()
    local list      = rendering.list
    local repeated  = rendering.repeated == v_yes
    local r_done    = rendering.done
    local r_alldone = rendering.alldone
    local done      = repeated and { } or r_done
    local alldone   = repeated and { } or r_alldone
    local doglobal  = rendering.method == v_global
    local traced    = { } -- todo: only if interactive (backlinks) or when tracing
    for listindex=1,#result do
        local r = result[listindex]
        local u = r.userdata
        if u and u.btxset == dataset then
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
                        local l = { tag, listindex, u.btxint, 0 }
                        list[#list+1] = l
                        traced[tag] = l
                    end
                else
                    done[tag]    = section
                    alldone[tag] = true
                    list[#list+1] = { tag, listindex, u.btxint, 0 }
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
end

methods[v_global] = methods[v_local]

function lists.collectentries(specification)
    local dataset = specification.btxdataset
    if not dataset then
        return
    end
    local rendering  = renderings[dataset]
    if not rendering then
        return
    end
    local method            = specification.method or v_none
    rendering.method        = method
    rendering.list          = { }
    rendering.done          = { }
    rendering.sorttype      = specification.sorttype  or v_default
    rendering.criterium     = specification.criterium or v_none
    rendering.repeated      = specification.repeated  or v_no
    rendering.specification = specification
    local filtermethod      = methods[method]
    if not filtermethod then
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
end

-- experiment

local splitspec = lpeg.splitat(S(":."))
local splitter  = sorters.splitters.utf
local strip     = sorters.strip

local function newsplitter(splitter)
    return setmetatableindex({},function(t,k) -- could be done in the sorter but seldom that many shared
        local v = splitter(k,true)                  -- in other cases
        t[k] = v
        return v
    end)
end

local template = [[
    local strip   = sorters.strip
    local writers = publications.writers
    return function(entry,detail,splitted,i) -- snippets
        return {
            index = i,
            split = { %s, splitted[tostring(i)] }
        }
    end
]]

local function byspec(dataset,list,method) -- todo: yearsuffix
    local luadata  = datasets[dataset].luadata
    local details  = datasets[dataset].details
    local result   = { }
    local splitted = newsplitter(splitter) -- saves mem
 -- local snippets = { } -- saves mem
    local fields   = settings_to_array(method)
    for i=1,#fields do
        local f = settings_to_array(fields[i])
        local r = { }
        for i=1,#f do
            local a, b = lpegmatch(splitspec,f[i])
            if b then
                if a == "detail" or a == "entry" then
                    local w = writers[b]
                    if w then
                     -- r[#r+1] = formatters["(%s.%s and writers[%q](%s.%s,snippets))"](a,b,b,a,b)
                        r[#r+1] = formatters["(%s.%s and writers[%q](%s.%s))"](a,b,b,a,b)
                    else
                        r[#r+1] = formatters["%s.%s"](a,b,a,b)
                    end
                end
            elseif a then
                r[#r+1] = formatters["%s"](a)
            end
        end
        r[#r+1] = '""'
        fields[i] = "splitted[strip(" .. concat(r," or ") .. ")]"
    end
    local action  = formatters[template](concat(fields,", "))
    local prepare = loadstring(action)
    if prepare then
        prepare = prepare()
        local dummy = { }
        for i=1,#list do
            -- either { tag, tag, ... } or { { tag, index }, { tag, index } }
            local li     = list[i]
            local tag    = type(li) == "string" and li or li[1]
            local entry  = luadata[tag]
            local detail = details[tag]
            if entry and detail then
                result[i] = prepare(entry,detail,splitted,i) -- ,snippets)
            else
                result[i] = prepare(dummy,dummy,splitted,i) -- ,snippets)
            end
        end
    end
    return result
end


lists.sorters = {
    [v_short] = function(dataset,rendering,list)
        local shorts = rendering.shorts
        local function compare(a,b)
            local aa, bb = a and a[1], b and b[1]
            if aa and bb then
                aa, bb = shorts[aa], shorts[bb]
                return aa and bb and aa < bb
            end
            return false
        end
        sort(list,compare)
    end,
    [v_reference] = function(dataset,rendering,list)
        local function compare(a,b)
            local aa, bb = a and a[1], b and b[1]
            if aa and bb then
                return aa and bb and aa < bb
            end
            return false
        end
        sort(list,compare)
    end,
    [v_dataset] = function(dataset,rendering,list)
        local function compare(a,b)
            local aa, bb = a and a[1], b and b[1]
            if aa and bb then
                aa, bb = list[aa].index or 0, list[bb].index or 0
                return aa and bb and aa < bb
            end
            return false
        end
        sort(list,compare)
    end,
 -- [v_default] = function(dataset,rendering,list) -- not really needed
 --     local ordered = rendering.ordered
 --     local function compare(a,b)
 --         local aa, bb = a and a[1], b and b[1]
 --         if aa and bb then
 --             aa, bb = ordered[aa], ordered[bb]
 --             return aa and bb and aa < bb
 --         end
 --         return false
 --     end
 --     sort(list,compare)
 -- end,
    [v_default] = function(dataset,rendering,list,sorttype) -- experimental
        if sorttype == "" or sorttype == v_default then
            local function compare(a,b)
                local aa, bb = a and a[4], b and b[4]
                if aa and bb then
                    return aa and bb and aa < bb
                end
                return false
            end
            sort(list,compare)
        else
            local valid = byspec(dataset,list,sorttype)
            if #valid == 0 or #valid ~= #list then
                -- nothing to sort
            else
                -- if needed we can wrap compare and use the list directly but this is cleaner
                sorters.sort(valid,sortcomparer)
                for i=1,#valid do
                    local v = valid[i]
                    valid[i] = list[v.index]
                end
                return valid
            end
        end
    end,
    [v_author] = function(dataset,rendering,list)
        local valid = publications.authors.sorters.author(dataset,list)
        if #valid == 0 or #valid ~= #list then
            -- nothing to sort
        else
            -- if needed we can wrap compare and use the list directly but this is cleaner
            sorters.sort(valid,sortcomparer)
            for i=1,#valid do
                local v = valid[i]
                valid[i] = list[v.index]
            end
            return valid
        end
    end,
}

-- for determining width

local lastnumber = 0 -- document wide

function lists.prepareentries(dataset)
    local rendering = renderings[dataset]
    local list      = rendering.list
    local used      = rendering.used
    local forceall  = rendering.criterium == v_all
    local repeated  = rendering.repeated == v_yes
    local sorttype  = rendering.sorttype or v_default
    local sorter    = lists.sorters[sorttype] or lists.sorters[v_default]
    local luadata   = datasets[dataset].luadata
    local details   = datasets[dataset].details
    local newlist   = { }
    for i=1,#list do
        local li    = list[i]
        local tag   = li[1]
        local entry = luadata[tag]
        if entry and (forceall or repeated or not used[tag]) then
            newlist[#newlist+1] = li
            -- already here:
            if not repeated then
                used[tag] = true -- beware we keep the old state (one can always use criterium=all)
            end
            local detail = details[tag]
            local number = detail.number
            if not number then
                lastnumber    = lastnumber + 1
                number        = lastnumber
                detail.number = lastnumber
            end
            li[4] = number
        end
    end
    rendering.list = type(sorter) == "function" and sorter(dataset,rendering,newlist,sorttype) or newlist
end

function lists.fetchentries(dataset)
    local rendering = renderings[dataset]
    local list      = rendering.list
    for i=1,#list do
        local li = list[i]
        ctx_btxsettag(li[1])
        ctx_btxsetnumber(li[4])
        ctx_btxchecklistentry()
    end
end

-- for rendering

function lists.flushentries(dataset)
    local rendering = renderings[dataset]
    local list      = rendering.list
    local luadata   = datasets[dataset].luadata
    for i=1,#list do
        local li       = list[i]
        local tag      = li[1]
        local n        = li[4]
        local entry    = luadata[tag]
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
        local bl = li[3]
        if bl and bl ~= "" then
            ctx_btxsetbacklink(bl)
            ctx_btxsetbacktrace(concat(li," ",3)) -- how about 4
            local uc = citetolist[tonumber(bl)]
            if uc then
                ctx_btxsetinternal(uc.references.internal or "")
            end
        else
            -- nothing
        end
        ctx_btxhandlelistentry()
     end
end

function lists.filterall(dataset)
    local r = renderings[dataset]
    local list = r.list
    local registered = r.registered
    for i=1,#registered do
        list[i] = { registered[i], i, false, 0 }
    end
end

commands.btxresolvelistreference = lists.resolve
commands.btxaddtolist            = lists.addentry
commands.btxcollectlistentries   = lists.collectentries
commands.btxpreparelistentries   = lists.prepareentries
commands.btxfetchlistentries     = lists.fetchentries
commands.btxflushlistentries     = lists.flushentries

local citevariants        = { }
publications.citevariants = citevariants

local optionalspace  = lpeg.patterns.whitespace^0
local prefixsplitter = optionalspace * lpeg.splitat(optionalspace * P("::") * optionalspace)

function commands.btxhandlecite(specification)
    local tag = specification.reference
    if not tag or tag == "" then
        return
    end
    --
    local dataset  = specification.dataset or "" -- standard
    local mark     = specification.markentry ~= false
    local variant  = specification.variant or "num"
    local sorttype = specification.sorttype
    local compress = specification.compress == v_yes
    local internal = specification.internal
    --
    local prefix, rest = lpegmatch(prefixsplitter,tag)
    if rest then
        dataset = prefix
    else
        rest = tag
    end
    local action = citevariants[variant] -- there is always fallback on default
    if trace_cite then
        report_cite("inject, dataset: %s, tag: %s, variant: %s, compressed",dataset or "-",rest,variant)
    end
    ctx_setvalue("currentbtxdataset",dataset)
    action(dataset,rest,mark,compress,variant,internal) -- maybe pass a table
end


function commands.btxhandlenocite(specification)
    local tag = specification.reference
    if not tag or tag == "" then
        return
    end
    --
    local dataset  = specification.dataset or "" -- standard
    local mark     = specification.markentry ~= false
    local internal = specification.internal or ""
    --
    local prefix, rest = lpegmatch(prefixsplitter,tag)
    if rest then
        dataset = prefix
    else
        rest = tag
    end
    --
    if trace_cite then
        report_cite("mark, dataset: %s, tags: %s",dataset or "-",rest)
    end
    --
    local reference = publications.parenttag(dataset,rest)
    local found, todo, list = findallused(dataset,reference,internal)
    tobemarked = mark and todo
    if found and tobemarked then
        flushmarked(dataset,list)
        commands.flushmarked() -- here (could also be done in caller)
    end
end

-- function commands.btxcitevariant(dataset,block,tags,variant) -- uses? specification ?
--     local action = citevariants[variant]
--     if action then
--         action(dataset,tags,variant)
--     end
-- end

-- sorter

local keysorter = function(a,b) return a.sortkey < b.sortkey end

local function compresslist(source)
    for i=1,#source do
        if type(source[i].sortkey) ~= "number" then
            return source
        end
    end
    local first, last, firstr, lastr
    local target, noftarget, tags = { }, 0, { }
    sort(source,keysorter)
    -- suffixes
    local oldvalue = nil
    local suffix   = 0
    local function setsuffix(entry,suffix,sortfld)
        entry.suffix  = suffix
        local dataset = datasets[entry.dataset]
        if dataset then
            local suffixes = dataset.suffixes[entry.tag]
            if suffixes then
                suffixes[sortfld] = suffix
            else
                dataset.suffixes[entry.tag] = { [sortfld] = suffix }
            end
        end
    end
    for i=1,#source do
        local entry   = source[i]
        local sortfld = entry.sortfld
        if sortfld then
            local value = entry.sortkey
            if value == oldvalue then
                if suffix == 0 then
                    suffix = 1
                    local entry = source[i-1]
                    setsuffix(entry,suffix,sortfld)
                end
                suffix = suffix + 1
                setsuffix(entry,suffix,sortfld)
            else
                oldvalue = value
                suffix   = 0
            end
        else
            break
        end
    end
    --
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

local function processcite(dataset,reference,mark,compress,setup,internal,getter,setter,compressor)
    reference = publications.parenttag(dataset,reference)
    local found, todo, list = findallused(dataset,reference,internal)
    tobemarked = mark and todo
--     if type(tobemarked) ~= "table" then
--         tobemarked = { }
--     end
    if found and setup then
        local source = { }
        local badkey = false
        for i=1,#found do
            local entry    = found[i]
            local tag      = entry.userdata.btxref
            local internal = entry.references.internal
            local data     = getter(dataset,tag,entry,internal)
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
            source[i] = data
        end

        local function flush(i,n,entry,tag)
            local tag = tag or entry.tag
            local currentcitation = markcite(dataset,tag)
            ctx_btxstartcite()
            ctx_btxsettag(tag)
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
            if not setter(entry,entry.last) then
                ctx_btxsetfirst(f_missing(tag))
            end
            ctx_btxsetconcat(concatstate(i,n))
            ctx_btxcitesetup(setup)
            ctx_btxstopcite()
        end

        if compress and not badkey then
            local target = (compressor or compresslist)(source)
            local nofcollected = #target
            if nofcollected == 0 then
                unknowncite(reference)
            else
                for i=1,nofcollected do
                    local entry = target[i]
                    local first = entry.first
                    if first then
                        flush(i,nofcollected,first,list[1]) -- somewhat messy as we can be sorted so this needs checking! might be wrong
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
        commands.flushmarked() -- here (could also be done in caller)
    end
end

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
    local v = function(dataset,tag,entry,internal)
        local value = getfield(dataset,tag,k)
        return {
            tag      = tag,
            internal = internal,
            [k]      = value,
            sortkey  = value,
            sortfld  = k,
        }
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

-- default

setmetatableindex(citevariants,function(t,k)
    local v = t.default
    t[k] = v
    return v
end)

function citevariants.default(dataset,reference,mark,compress,variant,internal)
    processcite(dataset,reference,mark,compress,variant,internal,setters[variant],getters[variant])
end

-- short

local function setter(dataset,tag,entry,internal)
    return {
        tag      = tag,
        internal = internal,
        short    = getfield(dataset,tag,"short"),
        suffix   = getfield(dataset,tag,"suffix"),
    }
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

function citevariants.short(dataset,reference,mark,compress,variant,internal)
    processcite(dataset,reference,mark,false,"short",internal,setter,getter)
end

-- pages (no compress)

local function setter(dataset,tag,entry,internal)
    return {
        dataset  = dataset,
        tag      = tag,
        internal = internal,
        pages    = getdetail(dataset,tag,"pages"),
    }
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

function citevariants.page(dataset,reference,mark,compress,variant,internal)
    processcite(dataset,reference,mark,compress,"page",internal,setter,getter)
end

-- num

local function setter(dataset,tag,entry,internal)
    local entries = entry.entries
    local text = entries and entries.text or "?"
    return {
        dataset  = dataset,
        tag      = tag,
        internal = internal,
        num      = text,
        sortkey  = text,
    }
end

local function getter(first,last)
    return simplegetter(first,last,"num")
end

function citevariants.num(dataset,reference,mark,compress,variant,internal)
    processcite(dataset,reference,mark,compress,"num",internal,setter,getter)
end

-- year

local function setter(dataset,tag,entry,internal)
    local year = getfield(dataset,tag,"year")
    return {
        dataset  = dataset,
        tag      = tag,
        internal = internal,
        year     = year,
        sortkey  = year,
        sortfld  = "year",
    }
end

local function getter(first,last)
    return simplegetter(first,last,"year")
end

function citevariants.year(dataset,reference,mark,compress,variant,internal)
    processcite(dataset,reference,mark,compress,"year",internal,setter,getter)
end

-- index | serial

local function setter(dataset,tag,entry,internal)
    local index = getfield(dataset,tag,"index")
    return {
        dataset  = dataset,
        tag      = tag,
        internal = internal,
        index    = index,
        sortkey  = index,
    }
end

local function getter(first,last)
    return simplegetter(first,last,"index")
end

function citevariants.index(dataset,reference,mark,compress,variant,internal)
    processcite(dataset,reference,mark,compress,"index",internal,setter,getter)
end

function citevariants.serial(dataset,reference,mark,compress,variant,internal)
    processcite(dataset,reference,mark,compress,"serial",internal,setter,getter)
end

-- category | type

local function setter(dataset,tag,entry,internal)
    return {
        dataset  = dataset,
        tag      = tag,
        internal = internal,
        category = getfield(dataset,tag,"category"),
    }
end

local function getter(first,last)
    return simplegetter(first,last,"category")
end

function citevariants.category(dataset,reference,mark,compress,variant,internal)
    processcite(dataset,reference,mark,compress,"category",internal,setter,getter)
end

function citevariants.type(dataset,reference,mark,compress,variant,internal)
    processcite(dataset,reference,mark,compress,"type",internal,setter,getter)
end

-- key | tag

local function setter(dataset,tag,entry,internal)
    return {
        dataset  = dataset,
        tag      = tag,
        internal = internal,
    }
end

local function getter(first,last)
    ctx_btxsetfirst(first.tag)
    return true
end

function citevariants.key(dataset,reference,mark,compress,variant,internal)
    return processcite(dataset,reference,mark,compress,"key",internal,setter,getter)
end

function citevariants.tag(dataset,reference,mark,compress,variant,internal)
    return processcite(dataset,reference,mark,compress,"tag",internal,setter,getter)
end

-- todo : sort
-- todo : choose between publications or commands namespace
-- todo : use details.author
-- todo : sort details.author
-- (name, name and name) .. how names? how sorted?
-- todo: we loop at the tex end .. why not here
-- \cite[{hh,afo},kvm]

-- common

local currentbtxciteauthor = function()
    context.currentbtxciteauthor()
    return true -- needed?
end

local function authorcompressor(found)
    local result  = { }
    local entries = { }
    for i=1,#found do
        local entry    = found[i]
        local author   = entry.author
        local aentries = entries[author]
        if aentries then
            aentries[#aentries+1] = entry
        else
            entries[author] = { entry }
        end
    end
    for i=1,#found do
        local entry    = found[i]
        local author   = entry.author
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
                ctx_btxsetfirst(first[key] or f_missing(first.tag))
                local suffix = entry.suffix
                local value  = entry.last[key]
                if suffix then
                    ctx_btxsetsecond(value .. converters.characters(suffix))
                else
                    ctx_btxsetsecond(value)
                end
            else
                local suffix = entry.suffix
                local value  = entry[key] or f_missing(tag)
                if suffix then
                    ctx_btxsetfirst(value .. converters.characters(suffix))
                else
                    ctx_btxsetfirst(value)
                end
            end
            ctx_btxsetconcat(concatstate(i,nofcollected))
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
    ctx_btxsetfirst(entry[key] or f_missing(tag))
    ctx_btxcitesetup(setup)
    ctx_btxstopciteauthor()
    ctx_btxstopsubcite()
end

local partialinteractive = false

local function authorgetter(first,last,key,setup) -- only first
 -- ctx_btxsetfirst(first.author)         -- unformatted
    ctx_btxsetfirst(currentbtxciteauthor) -- formatter (much slower)
    local entries = first.entries
    -- alternatively we can use a concat with one ... so that we can only make the
    -- year interactive, as with the concat
    if partialinteractive and not entries then
        entries = { first }
    end
    if entries then
        local c = compresslist(entries)
        local f = function() authorconcat(c,key,setup) return true end -- indeed return true?
        ctx_btxsetcount(#c)
        ctx_btxsetsecond(f)
    else
        local f = function() authorsingle(first,key,setup) return true end -- indeed return true?
        ctx_btxsetcount(0)
        ctx_btxsetsecond(f)
    end
    return true
end

-- author

local function setter(dataset,tag,entry,internal)
    return {
        dataset  = dataset,
        tag      = tag,
        internal = internal,
        author   = getfield(dataset,tag,"author"),
    }
end

local function getter(first,last,_,setup)
 -- ctx_btxsetfirst(first.author)         -- unformatted
    ctx_btxsetfirst(currentbtxciteauthor) -- formatter (much slower)
    return true
end

function citevariants.author(dataset,reference,mark,compress,variant,internal)
    processcite(dataset,reference,mark,false,"author",internal,setter,getter)
end

-- authornum

local function setter(dataset,tag,entry,internal)
    local text = entry.entries.text
    return {
        dataset  = dataset,
        tag      = tag,
        internal = internal,
        author   = getfield(dataset,tag,"author"),
        num      = text,
        sortkey  = text and lpegmatch(numberonly,text),
    }
end

local function getter(first,last)
    authorgetter(first,last,"num","author:num")
    return true
end

local function compressor(found)
    return authorcompressor(found) -- can be just an alias
end

function citevariants.authornum(dataset,reference,mark,compress,variant,internal)
    processcite(dataset,reference,mark,compress,"authornum",internal,setter,getter,compressor)
end

-- authoryear | authoryears

local function setter(dataset,tag,entry,internal)
    local year = getfield(dataset,tag,"year")
    return {
        dataset  = dataset,
        tag      = tag,
        internal = internal,
        author   = getfield(dataset,tag,"author"),
        year     = year,
        sortkey  = year and lpegmatch(numberonly,year),
        sortfld  = "year",
    }
end

local function getter(first,last)
    authorgetter(first,last,"year","author:year")
    return true
end

local function compressor(found)
    return authorcompressor(found)
end

function citevariants.authoryear(dataset,reference,mark,compress,variant,internal)
    processcite(dataset,reference,mark,compress,"authoryear",internal,setter,getter,compressor)
end

local function getter(first,last)
    authorgetter(first,last,"year","author:years")
    return true
end

function citevariants.authoryears(dataset,reference,mark,compress,variant,internal)
    processcite(dataset,reference,mark,compress,"authoryears",internal,setter,getter,compressor)
end

-- List variants

local listvariants        = { }
publications.listvariants = listvariants

function commands.btxlistvariant(dataset,block,tag,variant,listindex)
    local action = listvariants[variant] or listvariants.default
    if action then
        action(dataset,block,tag,variant,tonumber(listindex) or 0)
    end
end

function listvariants.default(dataset,block,tag,variant)
    ctx_btxsetfirst("?")
    ctx_btxlistsetup(variant)
end

function listvariants.num(dataset,block,tag,variant,listindex)
    ctx_btxsetfirst(listindex)
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
        ctx_btxsetsecond(suffix)
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
                        ctx_btxlistsetup(variant)
                    end
                end
            end
        end
    end
end
